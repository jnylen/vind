defmodule Shared.HttpClient.Middleware.ContentCache do
  @moduledoc """
  Implementation of HTTP cache

  Rewrite of https://github.com/plataformatec/faraday-http-cache

  ### Example
  ```
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.Cache, store: MyStore
  end
  ```

  ### Options
  - `:store`        - cache store, possible options: `Tesla.Middleware.Cache.Store.Redis`
  - `:mode`         - `:shared` (default) or `:private` (do cache when `Cache-Control: private`)
  """

  @behaviour Tesla.Middleware

  # alias Shared.HttpClient.Middleware.ContentCache.Store
  # alias Shared.HttpClient.Middleware.ContentCache.CacheControl
  alias Shared.HttpClient.Middleware.ContentCache.Request
  alias Shared.HttpClient.Middleware.ContentCache.Response
  alias Shared.HttpClient.Middleware.ContentCache.Storage
  alias Calendar.DateTime, as: CalDT

  @impl true
  def call(env, next, opts) do
    store = Keyword.fetch!(opts, :store)
    mode = Keyword.get(opts, :mode, :shared)
    request = Request.new(env)

    with {:ok, {env, _}} <- process(request, next, store, mode) do
      cleanup(env, store)
      {:ok, env}
    end
  end

  defp process(request, next, store, mode) do
    if Request.cacheable?(request) && has_required_opts?(request) do
      if Request.skip_cache?(request) do
        run_and_store(request, next, store, mode)
      else
        case fetch(request, store) do
          {:ok, response} ->
            if Response.fresh?(response) do
              {:ok, response}
            else
              with {:ok, response} <- validate(request, response, next) do
                store(request, response, store, mode)
              end
            end

          :not_found ->
            run_and_store(request, next, store, mode)
        end
      end
    else
      run(request, next)
    end
  end

  defp has_required_opts?(req) do
    unless is_nil(req.opts[:file_name]) || is_nil(req.opts[:folder_name]) do
      true
    else
      false
    end
  end

  defp run(env, next) do
    with {:ok, env} <- Tesla.run(env, next) do
      {:ok, Response.new(env, "skipped")}
    end
  end

  defp run_and_store(request, next, store, mode) do
    with {:ok, response} <- run(request, next) do
      store(request, response, store, mode)
    end
  end

  defp fetch(env, store) do
    case Storage.get(store, env) do
      {:ok, res} -> {:ok, Response.new(res, "cached")}
      :not_found -> :not_found
    end
  end

  defp store(req, res, store, mode) do
    if Response.cacheable?(res, mode) do
      Storage.put(store, req, ensure_date_header(ensure_no_status_header(res)))
    end

    {:ok, res}
  end

  defp ensure_no_status_header(env) do
    Tesla.delete_header(env, "x-cache-status")
  end

  defp ensure_date_header(env) do
    case Tesla.get_header(env, "x-cache-lastupdated") do
      nil ->
        Tesla.put_header(
          env,
          "x-cache-lastupdated",
          CalDT.Format.httpdate(DateTime.utc_now())
        )

      _ ->
        env
    end
  end

  defp validate(env, res, next) do
    env =
      env
      |> maybe_put_header("if-modified-since", Tesla.get_header(res, "last-modified"))
      |> maybe_put_header("if-none-match", Tesla.get_header(res, "etag"))

    case Tesla.run(env, next) do
      {:ok, %{status: 304, headers: headers}} ->
        res =
          Enum.reduce(headers, res, fn
            {k, _}, env when k in ["content-type", "content-length"] -> env
            {k, v}, env -> Tesla.put_header(env, k, v)
          end)

        {:ok, Response.new(res, "cached")}

      {:ok, env} ->
        case is_the_same(res, env) do
          true -> {:ok, Response.new(res, "cached")}
          false -> {:ok, Response.new(env, "updated")}
        end

      error ->
        error
    end
  end

  defp is_the_same(old, new) do
    try do
      hash_string(old.body) == hash_string(new.body)
    rescue
      _ -> hash_string(Jsonrs.encode!(old.body)) == hash_string(Jsonrs.encode!(new.body))
    end
  end

  defp hash_string(string) do
    :crypto.hash(:sha256, string)
    |> Base.encode16()
  end

  defp maybe_put_header(env, _, nil), do: env
  defp maybe_put_header(env, name, value), do: Tesla.put_header(env, name, value)

  @delete_headers ["location", "content-location"]
  defp cleanup(env, store) do
    if delete?(env) do
      for header <- @delete_headers do
        if location = Tesla.get_header(env, header) do
          Storage.delete(store, %{env | url: location})
        end
      end

      Storage.delete(store, env)
    end
  end

  defp delete?(%{method: method}) when method in [:head, :get, :trace, :options], do: false
  defp delete?(%{status: status}) when status in 400..499, do: false
  defp delete?(_env), do: true
end
