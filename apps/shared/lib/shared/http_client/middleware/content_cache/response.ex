defmodule Shared.HttpClient.Middleware.ContentCache.Response do
  @moduledoc """
  A HTTP Response
  """
  alias Shared.HttpClient.Middleware.ContentCache.CacheControl
  alias Calendar.DateTime, as: CalDT

  def new(env, status) do
    Tesla.put_header(env, "x-cache-status", status)
  end

  @cacheable_status [200, 203, 300, 301, 302, 307, 404, 410]
  def cacheable?(%{status: status}, _) when status in @cacheable_status, do: true
  def cacheable?(_env, _), do: false

  def fresh?(env) do
    # cond do
    # true -> age(env) < 3600
    # -> false
    false
    # end
  end

  defp expires(env) do
    with header when not is_nil(header) <- Tesla.get_header(env, "expires"),
         {:ok, date} <- CalDT.Parse.httpdate(header),
         {:ok, seconds, _, :after} <- CalDT.diff(date, DateTime.utc_now()) do
      seconds
    else
      _ -> nil
    end
  end
end
