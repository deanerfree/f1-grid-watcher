defmodule F1GridWatcherWeb.StatusComponents do
  use Phoenix.Component
  @moduledoc """
  Components for displaying status indicators.
  """
  @doc """
  Component to display a status indicator based on the given status.
  """
  attr :status, :atom, required: true
  @spec status_indicator(atom()) :: Phoenix.HTML.safe()
  def status_indicator(assigns) do
    ~H"""
    <%= case @status do %>
      <% :ok -> %>
        <div class="inline-block w-4 h-4 bg-green-500 rounded-full" title="Data is up to date"></div>
      <% :stale -> %>
        <div class="inline-block w-4 h-4 bg-yellow-500 rounded-full" title="Data may be outdated"></div>
      <% :error -> %>
        <div class="inline-block w-4 h-4 bg-red-500 rounded-full" title="Error fetching data"></div>
      <% :loading -> %>
        <div class="inline-block w-4 h-4 bg-blue-500 rounded-full" title="Loading data"></div>
    <% end %>
    """
  end
end
