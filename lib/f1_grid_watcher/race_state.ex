defmodule F1GridWatcher.RaceState do
  @moduledoc """
  GenServer for managing global F1 race state with error handling and retries.
  """
  use GenServer
  require Logger

  alias F1GridWatcher.OpenF1.Client
  alias F1GridWatcher.OpenF1.Types
  alias F1GridWatcher.Utils
  alias F1GridWatcher.F1Cache
  alias Supabase.PostgREST, as: Q
  alias F1GridWatcher.Supabase.SupabaseFetcher
  # retry constants
  @max_retries 3
  @retry_delay 2_000
  @loading_timeout 60_000  # 60 seconds for the handler to wait for loading
  @current_date Date.utc_today().year
  @current_year Date.utc_today().year

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get_selected_year() :: integer()
  def get_selected_year do
    GenServer.call(__MODULE__, :get_selected_year)
  end

  @spec set_selected_year(integer()) :: :ok
  def set_selected_year(year) do
    GenServer.cast(__MODULE__, {:set_selected_year, year})
  end

  @spec get_all_drivers() :: %{integer() => Types.driver()}
  def get_all_drivers do
    GenServer.call(__MODULE__, :get_all_drivers)
  end

  @spec get_drivers_by_meeting(integer()) :: %{integer() => Types.driver()}
  def get_drivers_by_meeting(meeting) do
    GenServer.call(__MODULE__, {:get_drivers_by_meeting, meeting})
  end

  @spec get_laps(integer(), integer()) :: list(Types.lap())
  def get_laps(meeting_key, session_key) do
    GenServer.call(__MODULE__, {:get_laps, meeting_key, session_key}, 30_000)
  end

  @spec get_recent_race_results() :: list(Types.session_result())
  def get_recent_race_results do
    GenServer.call(__MODULE__, :get_recent_race_results, 30_000)
  end

  @spec get_sessions(integer()) :: list(Types.session())
  def get_sessions(meeting_key) do
    GenServer.call(__MODULE__, {:get_sessions, meeting_key}, 30_000)
  end

  @spec get_data_status() :: map()
  def get_data_status do
    GenServer.call(__MODULE__, :get_data_status)
  end

  @spec refresh_data() :: :ok
  def refresh_data do
    GenServer.cast(__MODULE__, :refresh_data)
  end

  # Types

  @typedoc """
  The internal state of the RaceState GenServer.
  """
  @type state :: %{
          selected_year: integer(),
          drivers: %{integer() => Types.driver()},
          recent_results: list(Types.session_result()),
          last_refresh: DateTime.t() | nil,
          data_loaded: boolean(),
          errors: list(error()),
          data_status: :ok | :loading | :stale | :error
        }

  @typedoc """
  Error information stored in state.
  """
  @type error :: %{
          optional(:status) => integer(),
          optional(:reason) => term(),
          optional(:retry_count) => integer(),
          resource: String.t(),
          type: :client_error | :server_error | :network_error | :timeout | :exception | :unknown_error,
          timestamp: DateTime.t()
        }

  # Server Callbacks

  @impl true
  @spec init(keyword()) :: {:ok, state(), {:continue, :load_initial_data}}
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
  @spec handle_continue(:load_initial_data, state()) :: {:noreply, state()}
  def handle_continue(:load_initial_data, state) do
    Logger.info("Starting background data load...")
    Task.start(fn ->
      new_state = fetch_all_data(state)

      Process.send_after(self(), :loading_timeout, @loading_timeout)

      GenServer.cast(__MODULE__, {:data_loaded, new_state})
    end)
    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:set_selected_year, integer()}, state()) :: {:noreply, state()}
  def handle_cast({:set_selected_year, year}, state) do
    Logger.info("Year changed to #{year}")
    new_state = %{state | selected_year: year, data_status: :loading}

    Process.send_after(self(), :loading_timeout, @loading_timeout)

    Task.start(fn ->
      loaded_state = fetch_all_data(new_state)
      GenServer.cast(__MODULE__, {:data_loaded, loaded_state})
    end)
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(:refresh_data, state()) :: {:noreply, state()}
  def handle_cast(:refresh_data, state) do
    Logger.info("Refreshing race data...")
    new_state = %{state | data_status: :loading}

    Process.send_after(self(), :loading_timeout, @loading_timeout)

    Task.start(fn ->
      loaded_state = fetch_all_data(new_state)
      GenServer.cast(__MODULE__, {:data_loaded, loaded_state})
    end)
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:data_loaded, state()}, state()) :: {:noreply, state()}
  def handle_cast({:data_loaded, loaded_state}, _current_state) do
    Logger.info("Background data load completed with status: #{loaded_state.data_status}")
    {:noreply, loaded_state}
  end

  @impl true
  @spec handle_call(:get_data_status, GenServer.from(), state()) :: {:reply, map(), state()}
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
  @spec handle_call(:get_selected_year, GenServer.from(), state()) :: {:reply, integer(), state()}
  def handle_call(:get_selected_year, _from, state) do
    {:reply, state.selected_year, state}
  end

  @impl true
  @spec handle_call(:get_all_drivers, GenServer.from(), state()) :: {:reply, %{integer() => Types.driver()}, state()}
  def handle_call(:get_all_drivers, _from, state) do
    case state.data_status do
      :loading -> {:reply, %{}, state}  # Return empty while loading
      _ -> {:reply, state.drivers, state}
    end
  end

  @impl true
  @spec handle_call({:get_drivers_by_meeting, integer()}, GenServer.from(), state()) ::
          {:reply, %{integer() => Types.driver()}, state()}
  def handle_call({:get_drivers_by_meeting, meeting_key}, _from, state) do
    drivers = case fetch_drivers(meeting_key) do
      {:ok, drivers} -> drivers
      {:error, _} -> %{}
    end

    {:reply, drivers, state}
  end

  @impl true
  @spec handle_call({:get_sessions, integer()}, GenServer.from(), state()) ::
          {:reply, list(Types.session()), state()}
  def handle_call({:get_sessions, meeting_key}, _from, state) do
    sessions = case fetch_sessions(meeting_key) do
      {:ok, sessions} -> sessions
      {:error, _} -> []
    end

    {:reply, sessions, state}
  end

  @impl true
  @spec handle_call(:get_recent_race_results, GenServer.from(), state()) ::
          {:reply, list(Types.session_result()), state()}
  def handle_call(:get_recent_race_results, _from, state) do
    {:reply, state.recent_results, state}
  end

  @impl true
  @spec handle_call({:get_laps, integer(), integer()}, GenServer.from(), state()) ::
          {:reply, list(Types.lap()), state()}
  def handle_call({:get_laps, meeting_key, session_key}, _from, state) do
    laps = case fetch_laps(meeting_key, session_key) do
      {:ok, laps} -> laps
      {:error, _} -> []
    end

    {:reply, laps, state}
  end

  @impl true
  @spec handle_info(:loading_timeout, state()) :: {:noreply, state()}
  def handle_info(:loading_timeout, state) do
    case state.data_status do
      :loading ->
        Logger.warning("Data loading timed out after #{@loading_timeout}ms, marking as stale")
        new_state = %{state |
          data_status: :stale,
          errors: state.errors ++ [%{
            resource: "loading_timeout",
            type: :timeout,
            reason: "Data loading exceeded timeout",
            timestamp: DateTime.utc_now()
          }]
        }
        {:noreply, new_state}

      _ ->
        # Data already loaded, ignore timeout
        {:noreply, state}
    end
  end

  # Private Functions

  @spec fetch_all_data(state()) :: state()
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

  @spec fetch_drivers(integer() | nil) :: {:ok, %{integer() => Types.driver()}} | {:error, term()}
  defp fetch_drivers(meeting \\ nil) do
    F1Cache.fetch(:drivers, fn ->
      case Client.list_item("/drivers", %{meeting: meeting}) do
        {:ok, drivers} ->
          {:ok,
           drivers
           |> Enum.map(&{&1[:driver_number], &1})
           |> Map.new()}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @spec fetch_meetings(integer()) :: {:ok, list(Types.meeting())} | {:error, term()}
  defp fetch_meetings(year) do
    F1Cache.fetch(:meetings, fn ->
      case Client.list_item("/meetings", year: year) do
        {:ok, meetings} ->
          # IO.inspect(meetings, label: "Fetched meetings: ")
          {:ok, meetings}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @spec fetch_sessions(integer()) :: {:ok, list(Types.session())} | {:error, term()}
  defp fetch_sessions(meeting_key) do
    case Client.list_item("/sessions", %{meeting_key: meeting_key}) do
      {:ok, sessions} ->
        {:ok, sessions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_laps(integer(), integer()) :: {:ok, list(Types.lap())} | {:error, term()}
  defp fetch_laps(meeting_key, session_key) do
    case Client.list_item("/laps", %{meeting_key: meeting_key, session_key: session_key}) do
      {:ok, laps} ->
        {:ok, laps}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_with_retry((-> {:ok, term()} | {:error, term()}), term(), String.t(), non_neg_integer()) ::
          {term(), list(error())}
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

  @spec fetch_recent_results_safe(list(Types.meeting()), list(Types.session_result())) ::
          {list(Types.session_result()), list(error())}
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

  @spec fetch_recent_results(list(Types.meeting())) :: list(Types.session_result())
  defp fetch_recent_results(meetings_list) do
    sessions_list =
      Enum.take(meetings_list, -3)
      |> Enum.map(fn meeting ->
        Task.async(fn ->
          case Client.list_item("/sessions", %{
                 meeting_key: meeting[:meeting_key]
               }) do
            {:ok, sessions} ->
              {meeting[:meeting_key], sessions}

            {:error, reason} ->
              Logger.error(
                "Error fetching sessions for meeting #{meeting["meeting_key"]}: #{inspect(reason)}"
              )

              {meeting[:meeting_key], nil}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))
      |> Map.new()

    Enum.take(meetings_list, -3)
    |> Enum.map(fn meeting ->
      Task.async(fn ->
        F1Cache.fetch("session_results_#{meeting[:meeting_key]}", fn ->
          final_results =
            Utils.build_session_results_map(
              meeting[:meeting_key],
              sessions_list[meeting[:meeting_key]],
              10
            )

          %{
            meeting_name: meeting[:meeting_name],
            official_name: meeting[:meeting_official_name],
            circuit_name: meeting[:circuit_short_name],
            country: meeting[:country_name],
            date_start: Utils.format_datetime(meeting[:date_start]),
            date_end: Utils.add_days(meeting[:date_start], 3),
            year: meeting[:year],
            results: final_results
          }
        end)
      end)
    end)
    |> Enum.map(&Task.await(&1, 30_000))
  end

  @spec get_season_schedule(integer(), integer()) :: {:ok, list(map())} | {:error, term()}
  def get_season_schedule(project_id, year) do
    {:ok, client} = F1GridWatcher.Supabase.Client.get_client()

    query =
      Q.from(client, "content")
      |> Q.eq("project_id", project_id)
      |> Q.eq("content_type_id", 1)
      |> Q.eq("content->0->>year", to_string(year))
      |> Q.select("*", returning: true)
      # |> Q.execute()
      # IO.inspect(query, label: "Executing Supabase query for schedules: ")

    SupabaseFetcher.fetch(query, "schedules")
  end
end
