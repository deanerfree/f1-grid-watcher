defmodule F1GridWatcherWeb.PageController do
  use F1GridWatcherWeb, :controller

  def home(conn, _params) do
    alias F1GridWatcher.OpenF1.Client
    alias F1GridWatcher.Utils
    alias F1GridWatcher.F1Cache
    # The home page is often custom made,
    # so skip the default app layout.
    years = [2023, 2024, 2025]

    driver_task =
      Task.async(fn ->
        F1Cache.fetch(:drivers, fn ->
        case Client.list_item("/drivers", %{}) do
          {:ok, drivers} ->
            drivers
            |> Enum.map(&{&1["driver_number"], &1})
            |> Map.new()

          {:error, reason} ->
            IO.puts("Error fetching drivers: #{inspect(reason)}")
            %{}
        end
        end)
      end)

    meetings_task =
      Task.async(fn ->
        F1Cache.fetch(:meetings, fn ->
        case Client.list_item("/meetings", year: List.last(years)) do
          {:ok, meetings} ->
            Enum.take(meetings, -3)

          {:error, reason} ->
            IO.puts("Error fetching meetings: #{inspect(reason)}")
            []
        end
        end)
      end)

    # Wait for both to complete
    unique_driver_list = Task.await(driver_task)
    last_three_meetings = Task.await(meetings_task)

    sessions_list =
      last_three_meetings
      |> Enum.map(fn meeting ->
        Task.async(fn ->
          case Client.list_item("/sessions", %{
                 "meeting_key" => meeting["meeting_key"]
               }) do
            {:ok, sessions} ->
              # IO.puts("Sessions for meeting #{meeting["meeting_key"]}: #{inspect(sessions)}")
              {meeting["meeting_key"], sessions}

            {:error, reason} ->
              IO.puts(
                "Error fetching sessions for meeting #{meeting["meeting_key"]}: #{inspect(reason)}"
              )

              {meeting["meeting_key"], nil}
          end
        end)
      end)
      # Add this line to wait for all tasks
      |> Enum.map(&Task.await/1)
      |> Map.new()

    # # IO.puts("Driver list fetched: #{inspect(length(driver_list))} drivers")
    # IO.puts(
    #   "--------------------------------------------------------------------------------------"
    # )

    # IO.puts("Sessions for last three meetings: #{inspect(sessions_list)}")

    # IO.puts(
    #   "--------------------------------------------------------------------------------------"
    # )

    # IO.puts("Length of last three sessions map: #{inspect(map_size(sessions_list))}")

    # IO.puts(
    #   "--------------------------------------------------------------------------------------"
    # )

    # Concurrently build session results maps for each of the last three meetings

    results_last_three =
      last_three_meetings
      |> Enum.map(fn meeting ->
        # Start async task for each meeting
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
      # Wait for all tasks to complete
      |> Enum.map(&Task.await/1)

    # IO.inspect(drivers_by_number, label: "Driver details for unique drivers", pretty: true, width: 80)
    # IO.puts("Session results for last three meetings: #{inspect(results_last_three)}")

    render(conn, :home,
      layout: false,
      results_last_three: results_last_three,
      drivers_by_number: unique_driver_list
    )
  end
end
