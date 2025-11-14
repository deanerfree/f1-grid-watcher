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
  @spec driver_race_card(map()) :: Phoenix.HTML.safe()
  def driver_race_card(assigns) do
    ~H"""
    <% driver_details = @drivers_by_number[@driver_result[:driver_number]] %>
    <% is_first_place = @index == 0 %>

    <div class="grid overflow-hidden relative grid-cols-12 grid-rows-3 items-center p-2 bg-gradient-to-r rounded-2xl from-f1Pink/70 to-f1Carbon">
      <span class="col-span-1 col-start-1 row-start-2 text-lg text-center text-f1Yellow">
        {@driver_result[:position]}.
      </span>

      <img
        class={[
          "object-cover col-span-3 col-start-1 row-span-3 row-start-1 ml-10 w-20 h-20 rounded-full border-2 shadow-lg",
          (is_first_place && "z-10 border-f1Yellow") || "border-f1Carbon"
        ]}
        src={driver_details[:headshot_url]}
        style={"background: linear-gradient(to right, ##{driver_details[:team_colour]}CC, #D4D4D8);"}
        alt={driver_details[:team_name]}
      />

      <div class="flex flex-row col-span-7 col-start-6 row-start-1 gap-2 items-center text-lg text-f1Yellow">
        <span>{driver_details[:broadcast_name]}</span>
        <%= if is_first_place do %>
          <.render_svg class="w-7 h-7" svg_name="misc/crown" />
        <% end %>
      </div>
      <%= if is_first_place do %>
        <span class="col-span-7 col-start-6 row-start-2 text-sm italic text-f1Lavender">
          Duration: {lap_duration_to_minutes(@driver_result[:duration])}
        </span>
      <% else %>
        <span class="col-span-7 col-start-6 row-start-2 text-sm italic text-f1Lavender">
          Gap: +{@driver_result[:gap_to_leader]}
        </span>
      <% end %>
      <span class="col-span-7 col-start-6 row-start-3 text-sm text-f1Lavender">
        Laps: {@driver_result[:number_of_laps]}
      </span>

      <%= if is_first_place do %>
        <%!-- <.render_svg class="absolute -top-2 left-[63px] w-12 h-12 z-[999]" svg_name="misc/crown" /> --%>
      <% end %>

      <div
        class="flex items-center justify-center z-[999] absolute bottom-0 left-[94px] w-9 h-9 rounded-full border-2 border-f1Carbon"
        style={"background-color: ##{driver_details[:team_colour]};"}
      >
        <img
          class="w-full h-full p-1 z-[999]"
          src={team_logo_path(driver_details[:team_name])}
          alt={driver_details[:team_name]}
        />
      </div>
    </div>
    """
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
    <% driver_details = @drivers_by_number[@driver_result[:driver_number]] %>
    <div class="grid grid-cols-12 grid-rows-1 items-center p-1 bg-gradient-to-r rounded-2xl from-telemetry-blue/70 to-f1Carbon">
      <span class="col-span-1 col-start-1 row-start-1 text-lg text-center text-f1Lavender">
        {@driver_result[:position]}.
      </span>

      <img
        class="object-cover col-span-2 col-start-2 justify-self-center w-8 h-8 rounded-full border-2 shadow-lg border-f1Carbon"
        src={driver_details[:headshot_url]}
        style={"background: linear-gradient(to right, ##{driver_details[:team_colour]}CC, #D4D4D8);"}
        alt={driver_details[:team_name]}
      />
      <span class="col-span-6 col-start-4 text-lg text-f1Lavender">
        {driver_details[:broadcast_name]}
      </span>
      <div class="flex col-span-1 col-start-12 gap-2 items-center w-6 h-6">
        <img class="w-full h-full" src={team_logo_path(driver_details[:team_name])} />
      </div>
    </div>
    """
  end
end
