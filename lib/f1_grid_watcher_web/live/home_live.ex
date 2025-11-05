defmodule F1GridWatcherWeb.HomeLive do
  use F1GridWatcherWeb, :live_view
  alias F1GridWatcher.RaceState

  def mount(_params, _session, socket) do
    # Start the countdown timer
    if connected?(socket) do
      :timer.send_interval(1000, self(), :tick)
    end

    # Fetch your data (from the controller)
    drivers_by_number = RaceState.get_drivers()
    results_last_three = RaceState.get_recent_race_results()
    status = RaceState.get_data_status()

    IO.inspect(status, label: "Data status in HomeLive.mount :>>>", pretty: true)

    # IO.inspect(results_last_three,
    #   label: "Results last three in HomeLive.mount :>>>",
    #   pretty: true
    # )

    # IO.inspect(drivers_by_number, label: "Drivers by number in HomeLive.mount :>>>", pretty: true)

    # Handle flash messages based on status
    socket =
      case status.status do
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
       race_time: "2023-07-15T14:30:00Z",
       results_last_three: results_last_three,
       drivers_by_number: drivers_by_number,
       status: status
     )}
  end

  def handle_info(:tick, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col gap-6">
        <div class="grid grid-cols-3 gap-4 ">
          <div class="col-span-full">
            <div class="w-full">

    <!-- Optional: Show data status warning -->
              <% inspect(@status, label: "Data status :>>>", pretty: true) %>
              <%= if @status.status == :error do %>
                <div class="p-4 mb-4 text-yellow-700 bg-yellow-100 border-l-4 border-yellow-500">
                  <p class="font-bold">⚠️ Some data may be outdated</p>
                  <p class="text-sm">
                    We're having trouble fetching the latest information from the F1 API.
                  </p>
                </div>
              <% end %>
              <%= if @results_last_three != [] and @results_last_three > 0 do %>
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
