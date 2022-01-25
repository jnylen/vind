defmodule Shared.HttpClient.Middleware.ContentCache.Store do
  @moduledoc """
  Behaviour for stores.
  """

  alias Tesla.Env

  @type key :: binary
  @type entry :: {Env.status(), Env.headers(), Env.body(), Env.headers()}
  @type vary :: [binary]
  @type data :: entry | vary

  @callback get(key) :: {:ok, data} | :not_found
  @callback put(key, data) :: :ok
  @callback delete(key) :: :ok
end
