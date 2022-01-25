defmodule Shared.HttpClient.Middleware.ContentCache.Request do
  @moduledoc """
  HTTP Request
  """
  def new(env), do: env

  def cacheable?(%{method: method}) when method not in [:get, :head], do: false
  def cacheable?(_env), do: true

  def skip_cache?(_), do: false
end
