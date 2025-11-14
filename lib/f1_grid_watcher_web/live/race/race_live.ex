defmodule F1GridWatcherWeb.Race.RaceLive do
  use F1GridWatcherWeb, :live_view
  alias F1GridWatcher.RaceState

  def mount(%{"year" => year, "meeting" => meeting}, _session, socket) do
    # Load initial data
    # meeting_data = get_race_details(year, meeting)
    # convert meeting to integer
    drivers_by_number = RaceState.get_drivers_by_meeting(String.to_integer(meeting))
    meeting_info =
    IO.inspect(drivers_by_number, label: "Drivers by number in RaceLive.mount :>>>", pretty: true)

    {:ok,
     socket
     |> assign(:year, year)
     |> assign(:meeting, meeting)
     |> assign(:drivers_by_number, drivers_by_number)
    }
  end

end
