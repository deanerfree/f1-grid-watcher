defmodule F1GridWatcherWeb.SliderComponent do
  @moduledoc """
  Components for displaying race results.
  """
  use Phoenix.Component

  @doc """
  Component to display a single driver result card.
  """
  slot :inner_block, required: true
  attr :data_map, :map, required: true
  attr :drivers_by_number, :map, required: true
  attr :title, :string, default: ""
  @spec slider(map()) :: Phoenix.HTML.safe()
  def slider(assigns) do
    ~H"""
    <%= if @title != "" do %>
      <h2 class="px-0 py-8 text-3xl font-extrabold text-f1Lavender font-display">
        {@title}
      </h2>
    <% end %>
    <div
      phx-hook="Swiper"
      id={"swiper-#{String.replace(@title, " ", "-") |> String.downcase()}"}
      class="p-4 swiper bg-gradient-to-br from-f1Carbon via-f1Carbon via-100% to-f1Pink/20 dark:from-neutral-800 dark:via-neutral-800 dark:to-f1Yellow rounded-lg border-2 border-f1Yellow dark:border-neutral-300"
    >
      <div class="swiper-wrapper !w-full">
        {render_slot(@inner_block, %{data_map: @data_map, drivers_by_number: @drivers_by_number})}
      </div>

    <!-- Navigation buttons -->
      <div class="swiper-button-next !text-f1Lavender" />
      <div class="swiper-button-prev !text-f1Lavender" />

    <!-- Pagination -->
      <div class="swiper-pagination" />
    </div>
    """
  end
end
