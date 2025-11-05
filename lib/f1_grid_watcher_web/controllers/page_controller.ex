defmodule F1GridWatcherWeb.PageController do
  use F1GridWatcherWeb, :controller

  alias F1GridWatcher.RaceState

  def home(conn, _params) do
    drivers_by_number = RaceState.get_drivers()
    results_last_three = RaceState.get_recent_race_results()
    status = RaceState.get_data_status()

    IO.inspect(status, label: "Data status in PageController.home :>>>", pretty: true)

    IO.inspect(results_last_three,
      label: "Results last three in PageController.home :>>>",
      pretty: true
    )

    IO.inspect(drivers_by_number,
      label: "Drivers by number in PageController.home :>>>",
      pretty: true
    )

    # Maybe show a banner if data is stale
    conn =
      case status.status do
        :stale ->
          put_flash(conn, :warning, "Some data may be outdated due to API errors")

        :error ->
          put_flash(conn, :error, "Unable to fetch latest data. Showing cached results.")

        _ ->
          conn
      end

    render(conn, :home,
      layout: false,
      results_last_three: results_last_three,
      drivers_by_number: drivers_by_number,
      status: status
    )
  end
end
