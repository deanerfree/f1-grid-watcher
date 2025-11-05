defmodule F1GridWatcher.RaceState do
  @moduledoc """
  GenServer for managing global F1 race state with error handling and retries.
  """
  use GenServer
  require Logger

  alias F1GridWatcher.OpenF1.Client
  alias F1GridWatcher.Utils
  alias F1GridWatcher.F1Cache

  @max_retries 3
  # 2 seconds
  @retry_delay 2_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_selected_year do
    GenServer.call(__MODULE__, :get_selected_year)
  end

  def set_selected_year(year) do
    GenServer.cast(__MODULE__, {:set_selected_year, year})
  end

  def get_drivers do
    GenServer.call(__MODULE__, :get_drivers)
  end

  def get_recent_race_results do
    GenServer.call(__MODULE__, :get_recent_race_results, 30_000)
  end

  def get_data_status do
    GenServer.call(__MODULE__, :get_data_status)
  end

  def refresh_data do
    GenServer.cast(__MODULE__, :refresh_data)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting RaceState GenServer...")

    initial_state = %{
      selected_year: 2025,
      drivers: %{},
      recent_results: [],
      last_refresh: nil,
      data_loaded: false,
      errors: [],
      # :ok, :loading, :stale, :error
      data_status: :loading
    }

    {:ok, initial_state, {:continue, :load_initial_data}}
  end

  @impl true
  def handle_continue(:load_initial_data, state) do
    Logger.info("Loading initial race data...")
    new_state = fetch_all_data(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_selected_year, _from, state) do
    {:reply, state.selected_year, state}
  end

  @impl true
  def handle_call(:get_drivers, _from, state) do
    {:reply, state.drivers, state}
  end

  @impl true
  def handle_call(:get_recent_race_results, _from, state) do
    {:reply, state.recent_results, state}
  end

  @impl true
  def handle_call(:get_data_status, _from, state) do
    status_info = %{
      status: state.data_status,
      last_refresh: state.last_refresh,
      errors: state.errors,
      data_loaded: state.data_loaded
    }

    {:reply, status_info, state}
  end

  @impl true
  def handle_cast({:set_selected_year, year}, state) do
    Logger.info("Year changed to #{year}")
    new_state = %{state | selected_year: year}
    new_state = fetch_all_data(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:refresh_data, state) do
    Logger.info("Refreshing race data...")
    new_state = fetch_all_data(state)
    {:noreply, new_state}
  end

  # Private Functions

  defp fetch_all_data(state) do
    errors = []

    # Fetch drivers with retry
    {drivers, driver_errors} =
      fetch_with_retry(
        fn -> fetch_drivers() end,
        # fallback to existing data
        state.drivers,
        "drivers"
      )

    errors = errors ++ driver_errors

    # Fetch meetings with retry
    {meetings_list, meeting_errors} =
      fetch_with_retry(
        fn -> fetch_meetings(state.selected_year) end,
        # fallback to empty
        [],
        "meetings"
      )

    errors = errors ++ meeting_errors

    # Fetch recent race results
    {recent_results, result_errors} =
      fetch_recent_results_safe(meetings_list, state.recent_results)

    errors = errors ++ result_errors

    # Determine overall status
    data_status =
      cond do
        Enum.empty?(errors) -> :ok
        drivers == %{} and recent_results == [] -> :error
        not Enum.empty?(errors) -> :stale
        true -> :ok
      end

    %{
      state
      | drivers: drivers,
        recent_results: recent_results,
        last_refresh: DateTime.utc_now(),
        data_loaded: true,
        errors: errors,
        data_status: data_status
    }
  end

  defp fetch_drivers do
    F1Cache.fetch(:drivers, fn ->
      case Client.list_item("/drivers", %{}) do
        {:ok, drivers} ->
          {:ok,
           drivers
           |> Enum.map(&{&1["driver_number"], &1})
           |> Map.new()}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp fetch_meetings(year) do
    F1Cache.fetch(:meetings, fn ->
      case Client.list_item("/meetings", year: year) do
        {:ok, meetings} ->
          IO.inspect(meetings, label: "Fetched meetings: ")
          {:ok, meetings}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp fetch_with_retry(fetch_fn, fallback_data, resource_name, retry_count \\ 0) do
    case fetch_fn.() do
      {:ok, data} ->
        Logger.info("Successfully fetched #{resource_name}")
        {data, []}

      {:error, {:client_error, status, _body}} ->
        # 4xx errors - don't retry, log and use fallback
        error = %{
          resource: resource_name,
          type: :client_error,
          status: status,
          timestamp: DateTime.utc_now(),
          retry_count: retry_count
        }

        Logger.error("Client error fetching #{resource_name}: #{status}")
        {fallback_data, [error]}

      {:error, {:server_error, status, _body}} when retry_count < @max_retries ->
        # 5xx errors - retry with exponential backoff
        Logger.warning(
          "Server error fetching #{resource_name} (attempt #{retry_count + 1}/#{@max_retries}): #{status}"
        )

        Process.sleep(@retry_delay * :math.pow(2, retry_count))
        fetch_with_retry(fetch_fn, fallback_data, resource_name, retry_count + 1)

      {:error, {:server_error, status, _body}} ->
        # 5xx errors - max retries exceeded
        error = %{
          resource: resource_name,
          type: :server_error,
          status: status,
          timestamp: DateTime.utc_now(),
          retry_count: retry_count
        }

        Logger.error(
          "Server error fetching #{resource_name} after #{retry_count} retries: #{status}"
        )

        {fallback_data, [error]}

      {:error, {:network_error, reason}} when retry_count < @max_retries ->
        # Network errors - retry
        Logger.warning(
          "Network error fetching #{resource_name} (attempt #{retry_count + 1}/#{@max_retries}): #{inspect(reason)}"
        )

        Process.sleep(@retry_delay * :math.pow(2, retry_count))
        fetch_with_retry(fetch_fn, fallback_data, resource_name, retry_count + 1)

      {:error, {:network_error, reason}} ->
        # Network errors - max retries exceeded
        error = %{
          resource: resource_name,
          type: :network_error,
          reason: reason,
          timestamp: DateTime.utc_now(),
          retry_count: retry_count
        }

        Logger.error(
          "Network error fetching #{resource_name} after #{retry_count} retries: #{inspect(reason)}"
        )

        {fallback_data, [error]}

      {:error, reason} ->
        # Unknown error
        error = %{
          resource: resource_name,
          type: :unknown_error,
          reason: reason,
          timestamp: DateTime.utc_now(),
          retry_count: retry_count
        }

        Logger.error("Unknown error fetching #{resource_name}: #{inspect(reason)}")
        {fallback_data, [error]}
    end
  end

  defp fetch_recent_results_safe(meetings_list, fallback_results) do
    try do
      results = fetch_recent_results(meetings_list)
      {results, []}
    rescue
      e ->
        error = %{
          resource: "recent_results",
          type: :exception,
          reason: Exception.message(e),
          timestamp: DateTime.utc_now()
        }

        Logger.error("Exception fetching recent results: #{Exception.message(e)}")
        {fallback_results, [error]}
    end
  end

  defp fetch_recent_results(meetings_list) do
    sessions_list =
      Enum.take(meetings_list, -3)
      |> Enum.map(fn meeting ->
        Task.async(fn ->
          case Client.list_item("/sessions", %{
                 "meeting_key" => meeting["meeting_key"]
               }) do
            {:ok, sessions} ->
              {meeting["meeting_key"], sessions}

            {:error, reason} ->
              Logger.error(
                "Error fetching sessions for meeting #{meeting["meeting_key"]}: #{inspect(reason)}"
              )

              {meeting["meeting_key"], nil}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))
      |> Map.new()

    Enum.take(meetings_list, -3)
    |> Enum.map(fn meeting ->
      Task.async(fn ->
        F1Cache.fetch("session_results_#{meeting["meeting_key"]}", fn ->
          final_results =
            Utils.build_session_results_map(
              meeting["meeting_key"],
              sessions_list[meeting["meeting_key"]],
              10
            )

          %{
            meeting_name: meeting["meeting_name"],
            official_name: meeting["meeting_official_name"],
            circuit_name: meeting["circuit_short_name"],
            country: meeting["country_name"],
            date_start: Utils.format_datetime(meeting["date_start"]),
            date_end: Utils.add_days(meeting["date_start"], 3),
            year: meeting["year"],
            results: final_results
          }
        end)
      end)
    end)
    |> Enum.map(&Task.await(&1, 30_000))
  end
end
