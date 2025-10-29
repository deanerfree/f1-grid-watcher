# lib/f1_grid_watcher/openf1/client.ex
defmodule F1GridWatcher.OpenF1.Client do
  @moduledoc """
  HTTP client for the OpenF1 API.

  Provides functions to interact with the OpenF1 API endpoints.
  """

  require Logger

  @base_url "https://api.openf1.org/v1"

  # Configure a reusable Req client with sensible defaults
  defp client do
    Req.new(
      base_url: @base_url,
      # Retry on network errors and 5xx responses
      retry: :transient,
      max_retries: 3,
      # 15 seconds
      receive_timeout: 15_000,
      headers: [
        {"accept", "application/json"},
        {"user-agent", "F1GridWatcher/1.0"}
      ]
    )
  end

  @doc """
  Makes a GET request to the OpenF1 API.
  ## List of the OpenF1 endpoints
    - Car data: GET /v1/car_data
    - Drivers: GET /v1/drivers
    - Intervals: GET /v1/intervals
    - Laps: GET /v1/laps
    - Location: GET /v1/location
    - Meetings: GET /v1/meetings
    - Overtakes (beta): GET /v1/overtakes
    - Pit: GET /v1/pit
    - Position: GET /v1/position
    - Race control: GET /v1/race_control
    - Sessions: GET /v1/sessions
    - Session result (beta): GET /v1/session_result
    - Starting grid (beta): GET /v1/starting_grid
    - Stints: GET /v1/stints
    - Team radio: GET /v1/team_radio
    - Weather: GET /v1/weather

  ## Parameters
    - endpoint: The API endpoint (e.g., "/sessions")
    - params: Query parameters as a keyword list or map

  ## Examples
      iex> Client.get("/sessions", session_key: 9158)
      {:ok, [%{"session_key" => 9158, ...}]}

      iex> Client.get("/invalid")
      {:error, %{status: 404, body: ...}}
  """
  @spec get(String.t(), keyword() | map()) :: {:ok, term()} | {:error, term()}
  def get(endpoint, params \\ []) do
    Logger.debug("OpenF1 API request: #{endpoint} with params: #{inspect(params)}")

    client()
    |> Req.get(url: endpoint, params: params)
    |> handle_response()
  end

  @doc """
  Reusable function to list items from any OpenF1 API endpoint.

  ## Parameters
    - endpoint: The API endpoint string (e.g., "/sessions", "/meetings")
    - opts: Query parameters as a keyword list

  ## Examples
      iex> Client.list_item("/sessions", year: 2023)
      {:ok, [%{"session_key" => 9158, ...}]}

      iex> Client.list_item("/meetings", [])
      {:ok, [%{"meeting_key" => 1234, ...}]}
  """
  @spec list_item(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_item(endpoint, opts \\ []) do
    params = build_query_params(opts)
    get(endpoint, params)
  end

  # Private function to build query parameters
  defp build_query_params(opts) do
    opts
    |> Enum.filter(fn {_key, value} -> not is_nil(value) end)
    |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  # Response handlers

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}) do
    Logger.debug("OpenF1 API success: received #{inspect(length(body))} items")
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 400..499 do
    Logger.warning("OpenF1 API client error: #{status}")
    {:error, %{status: status, body: body, type: :client_error}}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 500..599 do
    Logger.error("OpenF1 API server error: #{status}")
    {:error, %{status: status, body: body, type: :server_error}}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    Logger.warning("OpenF1 API unexpected status: #{status}")
    {:error, %{status: status, body: body, type: :unexpected}}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    Logger.error("OpenF1 API network error: #{inspect(reason)}")
    {:error, %{type: :network_error, reason: reason}}
  end

  defp handle_response({:error, reason}) do
    Logger.error("OpenF1 API error: #{inspect(reason)}")
    {:error, reason}
  end
end
