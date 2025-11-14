defmodule F1GridWatcherWeb.HomeLive do
  use F1GridWatcherWeb, :live_view
  alias F1GridWatcher.RaceState
  alias F1GridWatcher.Utils

  def mount(params, _session, socket) do
    # Start the countdown timer
    if connected?(socket) do
      :timer.send_interval(1000, self(), :tick)
    end

    current_date =
      DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()
    current_year = String.slice(current_date, 0, 4)
      |> String.to_integer()

    {:ok, assign(socket,
      current_date: current_date,
      results_last_three: [],  # Empty initially
      drivers_by_number: %{},
      status: :loading,  # Track loading state
      current_year_plus: current_year + 1,
      selected_year: current_year,
      schedule: [],
      previous_race: nil,
      upcoming_race: nil
    ), temporary_assigns: []}

    # Fetch your data (from the controller)

    drivers_by_number = RaceState.get_all_drivers()
    results_last_three = RaceState.get_recent_race_results()
    selected_year =
      case params["year"] do
        nil -> current_year
        year_str -> String.to_integer(year_str)
      end
    status = RaceState.get_data_status()

    {:ok, [schedule]} = RaceState.get_season_schedule(1, selected_year)
    selected_year_schedule = schedule["content"]

    upcoming_race_index =
      Enum.find_index(selected_year_schedule, fn race ->
        race["date_start"] > current_date
      end)

    {previous_race, upcoming_race} =
      case Enum.find_index(selected_year_schedule, fn race -> race["date_start"] > current_date end) do
        nil -> {nil, nil}
        0 -> {nil, Enum.at(selected_year_schedule, 0)}
        index ->
          {Enum.at(selected_year_schedule, index - 1),
          Enum.at(selected_year_schedule, index)}
      end

    IO.inspect(status, label: "Data status in HomeLive.mount :>>>", pretty: true)


    # IO.inspect(results_last_three,
    #   label: "Results last three in HomeLive.mount :>>>",
    #   pretty: true
    # )

    # IO.inspect(drivers_by_number, label: "Drivers by number in HomeLive.mount :>>>", pretty: true)

    # Handle flash messages based on status
    socket =
      case status do
        :stale ->
          put_flash(socket, :warning, "Some data may be outdated due to API errors")

        :error ->
          put_flash(socket, :error, "Unable to fetch latest data. Showing cached results.")

        _ ->
          socket
      end

    # Assign ALL the data to the socket
    {:ok,
      assign(socket,
        current_date: current_date,
        results_last_three: results_last_three,
        drivers_by_number: drivers_by_number,
        status: status.status,
        current_year_plus: current_year + 1,
        selected_year: selected_year,
        schedule: selected_year_schedule,
        previous_race: previous_race,
        upcoming_race: upcoming_race,
        current_date: current_date
     ), temporary_assigns: []}
  end

  def handle_params(params, _uri, socket) do
    current_year = Date.utc_today().year

    selected_year =
      case params["year"] do
        nil -> current_year
        year_str -> String.to_integer(year_str)
      end

    # Trigger async data loading
    send(self(), {:load_initial_data, selected_year, params["meeting"]})

    {:noreply, assign(socket, selected_year: selected_year, status: :loading)}
  end

  def handle_event("year_changed", %{"year" => year}, socket) do
    current_date = socket.assigns.current_date
    {:ok, [schedule]} = RaceState.get_season_schedule(1, String.to_integer(year))
    schedule = schedule["content"]

    {past_races, future_races} =
      Enum.split_while(schedule, fn race ->
        race["date_start"] <= current_date
      end)

    {:noreply, assign(socket,
      schedule: schedule,
      selected_year: String.to_integer(year),
      previous_race: List.last(past_races),
      upcoming_race: List.first(future_races)
    )}
  end

  def handle_event("apply_filters", %{"year" => year, "meeting" => meeting}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/#{year}/#{meeting}")}
  end

    def handle_info({:load_initial_data, year, meeting_slug}, socket) do
    current_date = socket.assigns.current_date

    # Load schedule
    {:ok, [schedule]} = RaceState.get_season_schedule(1, year)
    selected_year_schedule = schedule["content"]
    # IO.inspect(schedule["content"], label: "Selected year schedule in HomeLive.handle_info :>>>", pretty: true)

    # Find previous/upcoming races
    {previous_race, upcoming_race} =
      case Enum.find_index(selected_year_schedule, fn race -> race["date_start"] > current_date end) do
        nil -> {nil, nil}
        0 -> {nil, Enum.at(selected_year_schedule, 0)}
        index ->
          {Enum.at(selected_year_schedule, index - 1),
           Enum.at(selected_year_schedule, index)}
      end

    # Update with schedule first
    socket = assign(socket,
      schedule: selected_year_schedule,
      previous_race: previous_race,
      upcoming_race: upcoming_race
    )

    # Now load the slow data
    send(self(), :load_results)

    {:noreply, socket}
  end

  def handle_info(:load_results, socket) do
    # Load the slow data
    drivers_by_number = RaceState.get_all_drivers()
    results_last_three = RaceState.get_recent_race_results()
    status = RaceState.get_data_status()

    IO.inspect(status, label: "Data status in HomeLive.handle_info :>>>", pretty: true)

    # Handle flash messages
    socket =
      case status do
        :stale ->
          put_flash(socket, :warning, "Some data may be outdated due to API errors")
        :error ->
          put_flash(socket, :error, "Unable to fetch latest data. Showing cached results.")
        _ ->
          socket
      end

    {:noreply, assign(socket,
      results_last_three: results_last_three,
      drivers_by_number: drivers_by_number,
      status: status.status
    )}
  end

  def handle_info(:tick, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col gap-6">
        <div class="grid grid-cols-3 gap-4 items-center px-4 py-2 rounded-lg border border-neutral-800 dark:border-neutral-300">
          <form phx-submit="apply_filters" class="flex flex-row col-span-full gap-4 items-center">
            <select
              name="year"
              id="year"
              phx-change="year_changed"
              class="block w-24 bg-white rounded-md border border-gray-300 shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
              <%= for year <- 2023..@current_year_plus do %>
                <option value={year} selected={year == @selected_year}><%= year %></option>
              <% end %>
            </select>

            <select
              name="meeting"
              id="meeting_dropdown"
              class="block bg-white rounded-md border border-gray-300 shadow-sm w-fit focus:border-zinc-400 focus:ring-0 sm:text-sm">
              <%= for race <- @schedule do %>
                <option value={race["meeting_key"]} selected={@previous_race && race["meeting_name"] == @previous_race["meeting_name"]}>
                  <%= race["meeting_name"] %>
                </option>
              <% end %>
            </select>

            <.button type="submit" class="px-4 py-2 text-white rounded-md bg-f1Pink hover:bg-f1PinkDark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-f1PinkDark">
              Get Results
            </.button>
          </form>
        </div>
        <div class="grid grid-cols-3 gap-4 ">
          <div class="col-span-full">
            <div class="w-full">

              <% inspect(@status, label: "Data status :>>>", pretty: true) %>
              <%= if @status != :ok do %>
                <.status_indicator status={@status} />
              <% end %>
              <%= if @results_last_three != [] and @results_last_three > 0 and @status == :ok do %>
                <.slider
                  :let={data}
                  title="Last 3 Events"
                  drivers_by_number={@drivers_by_number}
                  data_map={@results_last_three}
                >
                  <%= for race <- Enum.reverse(data.data_map) do %>
                    <%!-- <% IO.inspect(race, label: "Race data") %> --%>
                    <div class="!flex !flex-col px-16 py-10 gap-8 swiper-slide text-f1Lavender dark:text-f1Carbon">
                      <h3 class="text-3xl font-semibold font-display text-f1Lavender">
                        {race[:official_name]}
                      </h3>
                      <div class="!flex !flex-col gap-4">
                        <%= for {session_key, session} <- Enum.reverse(race[:results]) do %>
                          <%!-- <% IO.inspect(session_key, label: "Session data") %>
                            <% IO.inspect(session, label: "Session data") %> --%>
                          <%= if session["session_type"] == "Race" && session["session_name"] == "Race" do %>
                            <h3 class="text-2xl font-semibold font-display text-f1Yellow">
                              {session["session_name"]} - {session["session_type"]}
                            </h3>
                            <div class="flex flex-row gap-4">
                              <div class="space-y-4 w-1/2">
                                <%= for {driver_result, index} <- Enum.with_index(Enum.slice(session["results"], 0..2)) do %>
                                  <.driver_race_card
                                    index={index}
                                    session_name={session["session_name"]}
                                    session_type={session["session_type"]}
                                    driver_result={driver_result}
                                    drivers_by_number={@drivers_by_number}
                                  />
                                <% end %>
                              </div>
                              <div class="space-y-2 w-1/2">
                                <%= for {driver_result, index} <- Enum.with_index(Enum.slice(session["results"], 3..20)) do %>
                                  <.results_grid
                                    index={index}
                                    session_name={session["session_name"]}
                                    session_type={session["session_type"]}
                                    driver_result={driver_result}
                                    drivers_by_number={@drivers_by_number}
                                  />
                                <% end %>
                              </div>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                      <div class="flex flex-col">
                        <span class="text-sm text-f1Yellow">
                          {race[:meeting_name]} - {race[:circuit_name]}
                        </span>
                        <span class="text-sm text-f1Yellow">
                          {race[:date_start]} - {race[:date_end]}
                        </span>
                      </div>
                    </div>
                  <% end %>
                </.slider>
              <% end %>
            </div>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-4 p-4 rounded-lg border border-neutral-800 dark:border-neutral-300">
          <div>Locations</div>
        </div>
      </div>
    """
  end
end
