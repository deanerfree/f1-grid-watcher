defmodule F1GridWatcher.Supabase.SupabaseFetcher do
  alias Supabase.PostgREST, as: Q
  require Logger

  @max_retries 3
  @retry_delay 1000

  @doc """
  Executes a Supabase query with retry logic and proper error handling.
  """
  def fetch(query, resource_name, opts \\ []) do
    fallback_data = Keyword.get(opts, :fallback, nil)
    retry_count = Keyword.get(opts, :retry_count, 0)

    case Q.execute(query) do
      # Success - 2xx responses
      %Supabase.Fetcher.Response{status: status, body: body} when status in 200..299 ->
        # IO.inspect(body, label: "Response body for #{resource_name}: ")
        case Jason.decode(body) do
          {:ok, data} ->
            # IO.inspect(data, label: "Fetched #{resource_name}: ")
            Logger.info("Successfully fetched #{resource_name} (#{length(data)} records)")
            {:ok, data}

          {:error, reason} ->
            Logger.error("Failed to decode JSON for #{resource_name}: #{inspect(reason)}")
            if fallback_data, do: {:ok, fallback_data}, else: {:error, :json_decode_error}
        end

      # Client errors - 4xx (don't retry)
      %Supabase.Fetcher.Response{status: status, body: body} when status in 400..499 ->
        Logger.error("Client error fetching #{resource_name}: #{status} - #{body}")

        error = %{
          type: :client_error,
          status: status,
          body: body,
          resource: resource_name
        }

        if fallback_data, do: {:ok, fallback_data}, else: {:error, error}

      # Server errors - 5xx (retry)
      %Supabase.Fetcher.Response{status: status, body: body} when status in 500..599 ->
        if retry_count < @max_retries do
          Logger.warning(
            "Server error fetching #{resource_name} (attempt #{retry_count + 1}/#{@max_retries}): #{status}"
          )

          Process.sleep(@retry_delay * round(:math.pow(2, retry_count)))
          fetch(query, resource_name, Keyword.put(opts, :retry_count, retry_count + 1))
        else
          Logger.error("Server error fetching #{resource_name} after #{retry_count} retries: #{status}")

          error = %{
            type: :server_error,
            status: status,
            body: body,
            resource: resource_name,
            retry_count: retry_count
          }

          if fallback_data, do: {:ok, fallback_data}, else: {:error, error}
        end

      # Unexpected response format
      other ->
        Logger.error("Unexpected response format for #{resource_name}: #{inspect(other)}")

        error = %{
          type: :unexpected_response,
          response: other,
          resource: resource_name
        }

        if fallback_data, do: {:ok, fallback_data}, else: {:error, error}
    end
  end

  @doc """
  Fetch with automatic fallback to empty list on error.
  """
  def fetch!(query, resource_name) do
    case fetch(query, resource_name, fallback: []) do
      {:ok, data} -> data
      {:error, _} -> []
    end
  end
end
