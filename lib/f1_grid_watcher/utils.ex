defmodule F1GridWatcher.Utils do
  alias F1GridWatcher.OpenF1.Client
  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  @moduledoc """
  Utility functions for F1GridWatcher.
  """

  @doc """
    Convert lap duration to minutes:seconds.milliseconds format from seconds.
    ## Examples
      iex> F1GridWatcher.Utils.lap_duration_to_minutes(90.22)
      "1:30.220"
  """
  @spec lap_duration_to_minutes(float()) :: String.t()
  def lap_duration_to_minutes(duration_seconds) do
    # Convert seconds to milliseconds for easier calculation
    total_ms = round(duration_seconds * 1000)

    hours = div(total_ms, 3_600_000)
    minutes = div(rem(total_ms, 3_600_000), 60_000)
    seconds = div(rem(total_ms, 60_000), 1000)
    milliseconds = rem(total_ms, 1000)

    "#{hours}:#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}.#{String.pad_leading(Integer.to_string(milliseconds), 3, "0")}"
  end

  @doc """
  Simplify iso8601 datetime string to date string.
  ## Examples

      iex> F1GridWatcher.Utils.format_datetime("2023-07-15T14:30:00Z")
      "15-07-2023"

      iex> F1GridWatcher.Utils.format_datetime("invalid-datetime")
      "invalid-datetime"
  """
  @spec format_datetime(String.t()) :: String.t()
  def format_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} ->
        Calendar.strftime(datetime, "%d %b %Y")

      {:error, _} ->
        datetime_string
    end
  end

  @doc """
    Add days to an iso8601 date string.
    ## Examples
      iex> F1GridWatcher.Utils.add_days("2023-07-15", 3)
      "2023-07-18"

      iex> F1GridWatcher.Utils.add_days("invalid-date", 3)
      "invalid-date"
  """
  @spec add_days(String.t(), integer()) :: String.t()
  def add_days(datetime_or_date_string, days) do
    # Try parsing as datetime first
    case DateTime.from_iso8601(datetime_or_date_string) do
      {:ok, datetime, _offset} ->
        new_datetime = DateTime.add(datetime, days * 86400, :second)
        format_datetime(DateTime.to_iso8601(new_datetime))

      {:error, _} ->
        # If that fails, try parsing as date
        case Date.from_iso8601(datetime_or_date_string) do
          {:ok, date} ->
            new_date = Date.add(date, days)
            Date.to_iso8601(new_date)

          {:error, _} ->
            datetime_or_date_string
        end
    end
  end

  @doc """
  Generate the path to a team's logo image based on the team name.
  Assumes logos are stored in "priv/static/images/team_logos/" with filenames
  formatted as lowercase, spaces replaced with underscores, and suffixed with "_logo.webp".
  ## Examples
  iex> F1GridWatcher.Utils.team_logo_path("Red Bull Racing")
  "/images/team_logos/red_bull_racing_logo.webp"
  iex> F1GridWatcher.Utils.team_logo_path("McLaren")
  """
  @spec team_logo_path(String.t()) :: String.t()
  def team_logo_path(team_name) do
    logo_filename =
      team_name
      |> String.downcase()
      |> String.replace(" ", "_")
      |> Kernel.<>("_logo.webp")

    "/images/team_logos/#{logo_filename}"
  end

  @doc """
    Build a map of session results for a given meeting key and session.
    ## Examples
      iex> F1GridWatcher.Utils.build_session_results_map(1234, [%{"session_key" => 1}, %{"session_key" => 2}, %{"session_key" => 3}])
      %{
        session_1: [...],
        session_2: [...],
        session_3: [...]
      }
  """
  @spec build_session_results_map(integer(), map(), integer()) :: map()
  def build_session_results_map(meeting_key, sessions, position_limit) do
    # IO.puts("Sessions length for meeting_key #{meeting_key}: #{inspect(length(sessions))}")
    session_count = length(sessions)
    session_1 = Enum.at(sessions, session_count - 3)
    session_2 = Enum.at(sessions, session_count - 2)
    session_3 = Enum.at(sessions, session_count - 1)

    # Start all 3 requests concurrently
    task_1 =
      Task.async(fn ->
        case Client.list_item("/session_result", %{
               "meeting_key" => meeting_key,
               "session_key" => session_1[:session_key],
               "position<" => position_limit
             }) do
          {:ok, results} ->
            results

          {:error, reason} ->
            IO.puts("Error fetching session 1 results: #{inspect(reason)}")
            []
        end
      end)

    task_2 =
      Task.async(fn ->
        case Client.list_item("/session_result", %{
               "meeting_key" => meeting_key,
               "session_key" => session_2[:session_key],
               "position<" => position_limit
             }) do
          {:ok, results} ->
            results

          {:error, reason} ->
            IO.puts("Error fetching session 2 results: #{inspect(reason)}")
            []
        end
      end)

    task_3 =
      Task.async(fn ->
        case Client.list_item("/session_result", %{
               "meeting_key" => meeting_key,
               "session_key" => session_3[:session_key],
               "position<" => position_limit
             }) do
          {:ok, results} ->
            results

          {:error, reason} ->
            IO.puts("Error fetching session 3 results: #{inspect(reason)}")
            []
        end
      end)

    # Wait for all results (default timeout is 5 seconds)
    session_1_result = Task.await(task_1)
    session_2_result = Task.await(task_2)
    session_3_result = Task.await(task_3)

    %{
      session_1: %{
        session_type: session_1[:session_type],
        session_name: session_1[:session_name],
        results: session_1_result
      },
      session_2: %{
        session_type: session_2[:session_type],
        session_name:  session_2[:session_name],
        results: session_2_result
      },
      session_3: %{
        session_type: session_3[:session_type],
        session_name: session_3[:session_name],
        results: session_3_result
      }
    }
  end

  @doc """
  Helper functions for loading and rendering SVG files as components.
  """

  attr :svg_name, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global
  @spec render_svg(map()) :: Phoenix.HTML.safe()
  def render_svg(assigns) do
    case load_svg(assigns.svg_name) do
      {:ok, svg_content} ->
        svg_with_attrs = inject_attributes(svg_content, assigns)
        assigns = assign(assigns, :svg_content, svg_with_attrs)

        ~H"""
        {raw(@svg_content)}
        """

      {:error, _reason} ->
        ~H"""
        <svg class={@class} {@rest} viewBox="0 0 24 24">
          <text x="12" y="12" text-anchor="middle">?</text>
        </svg>
        """
    end
  end

  @spec load_svg(String.t()) :: {:ok, String.t()} | {:error, File.posix()}
  def load_svg(name) do
    app_dir = Application.app_dir(:f1_grid_watcher, "priv/static/images")
    path = Path.join(app_dir, "#{name}.svg")
    File.read(path)
  end

  @spec inject_attributes(String.t(), map()) :: String.t()
  def inject_attributes(svg_content, assigns) do
    attrs = build_svg_attributes(assigns)

    # Remove existing width and height attributes from the SVG
    svg_content =
      svg_content
      |> String.replace(~r/width="[^"]*"/, "")
      |> String.replace(~r/height="[^"]*"/, "")

    String.replace(
      svg_content,
      ~r/<svg([^>]*)>/,
      "<svg\\1 #{attrs} width=\"100%\" height=\"100%\">"
    )
  end

  @spec build_svg_attributes(map()) :: String.t()
  def build_svg_attributes(assigns) do
    attrs = []

    attrs = if assigns.class != "", do: ["class=\"#{assigns.class}\"" | attrs], else: attrs

    attrs =
      Enum.reduce(assigns[:rest] || %{}, attrs, fn {key, value}, acc ->
        ["#{key}=\"#{value}\"" | acc]
      end)

    Enum.join(attrs, " ")
  end
end
