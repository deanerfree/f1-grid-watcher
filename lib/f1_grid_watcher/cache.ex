defmodule F1GridWatcher.F1Cache do
  @cache_name :f1_cache
  @default_ttl :timer.minutes(15)

  def fetch(cache_key, fetch_fn, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        # Cache miss - execute the fetch function
        IO.puts("Cache miss #{@cache_name} for key: #{inspect(cache_key)}")
        result = fetch_fn.()
        Cachex.put(@cache_name, cache_key, result, ttl: ttl)
        result

      {:ok, cached_data} ->
        IO.puts("Cache hit for key: #{inspect(cache_key)}")
        # Cache hit
        cached_data

      {:error, :no_cache} ->
        # Cache not started/available - fetch without caching
        IO.warn("Cache :#{@cache_name} not available, fetching without cache")
        fetch_fn.()

      {:error, reason} ->
        # Other cache errors - fallback to fetch
        IO.warn("Cache error: #{inspect(reason)}, fetching without cache")
        fetch_fn.()
    end
  end

  def invalidate(cache_key) do
    Cachex.del(@cache_name, cache_key)
  end

  def invalidate_all do
    Cachex.clear(@cache_name)
  end
end
