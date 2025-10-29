defmodule F1GridWatcherWeb.ResultsComponents do
  @moduledoc """
  Components for displaying race results.
  """
  import F1GridWatcher.Utils
  use Phoenix.Component


  @doc """
  Component to display a single driver result card.
  """
  attr :driver_result, :map, required: true
  attr :drivers_by_number, :map, required: true
  attr :session_name, :string, required: false
  attr :session_type, :string, required: false
  attr :index, :integer, required: false

  def driver_race_card(assigns) do
      IO.inspect(assigns.index, label: "Driver Result Card Index")
    case assigns.index do
      0 ->
        ~H"""
        <% driver_details = @drivers_by_number[@driver_result["driver_number"]] %>
        <div class="grid overflow-hidden relative grid-cols-12 grid-rows-3 items-center p-2 bg-gradient-to-r rounded-2xl from-f1Pink/70 to-f1Carbon">
          <span class="col-span-1 col-start-1 row-start-2 text-lg text-center text-f1Yellow">{@driver_result["position"]}. </span>
          <img
          class="object-cover z-10 col-span-3 col-start-1 row-span-3 row-start-1 ml-10 w-20 h-20 rounded-full border-2 shadow-lg border-f1Yellow"
          src={driver_details["headshot_url"]}
          style={"background: linear-gradient(to right, ##{driver_details["team_colour"]}CC, #D4D4D8);"}
          alt={driver_details["team_name"]}
          />
          <span class="col-span-7 col-start-6 row-start-2 text-lg text-f1Yellow">
            {driver_details["broadcast_name"]}
          </span>
          <.render_svg class="absolute -top-2 left-[63px] w-12 h-12 z-[999]" svg_name={"misc/crown"} />
        </div>
      """

      _ ->
    ~H"""
    <% driver_details = @drivers_by_number[@driver_result["driver_number"]] %>
    <div class="grid overflow-hidden grid-cols-12 grid-rows-3 items-center p-2 bg-gradient-to-r rounded-2xl from-f1Pink/70 to-f1Carbon">
      <span class="col-span-1 col-start-1 row-start-2 text-lg text-center text-f1Yellow">{@driver_result["position"]}. </span>
      <img
        class="object-cover col-span-3 col-start-1 row-span-3 row-start-1 ml-10 w-20 h-20 rounded-full border-2 shadow-lg border-f1Carbon"
        src={driver_details["headshot_url"]}
        style={"background: linear-gradient(to right, ##{driver_details["team_colour"]}CC, #D4D4D8);"}
        alt={driver_details["team_name"]}
      />
      <span class="col-span-7 col-start-6 row-start-2 text-lg text-f1Yellow">
        {driver_details["broadcast_name"]}
      </span>
      <%!-- <div class="flex col-span-4 col-start-2 row-start-3 gap-2 items-center">
        <img src={Utils.team_logo_path(driver_details["team_name"])} />
        <span class="text-lg text-f1Yellow">- {driver_details["team_name"]}</span>
      </div> --%>
    </div>
    """
    end
  end

  @doc """
  Component to display basic driver results for a session.
  """
  attr :driver_result, :map, required: true
  attr :drivers_by_number, :map, required: true
  attr :session_name, :string, required: false
  attr :session_type, :string, required: false
  attr :index, :integer, required: false
  def results_grid(assigns) do
    ~H"""
    <% driver_details = @drivers_by_number[@driver_result["driver_number"]] %>
    <div class="grid overflow-hidden grid-cols-12 grid-rows-1 items-center p-1 bg-gradient-to-r rounded-2xl from-telemetry-blue/70 to-f1Carbon">
      <span class="col-span-1 col-start-1 row-start-1 text-lg text-center text-f1Yellow">
        {@driver_result["position"]}.
      </span>

      <img
        class="object-cover col-span-2 col-start-2 justify-self-center w-8 h-8 rounded-full border-2 shadow-lg border-f1Carbon"
        src={driver_details["headshot_url"]}
        style={"background: linear-gradient(to right, ##{driver_details["team_colour"]}CC, #D4D4D8);"}
        alt={driver_details["team_name"]}
      />
      <span class="col-span-6 col-start-4 text-lg text-f1Yellow">
        {driver_details["broadcast_name"]}
      </span>
      <%!-- <div class="flex col-span-4 col-start-2 row-start-3 gap-2 items-center">
        <img src={Utils.team_logo_path(driver_details["team_name"])} />
        <span class="text-lg text-f1Yellow">- {driver_details["team_name"]}</span>
      </div> --%>
    </div>
    """
  end
end
