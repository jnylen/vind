defmodule FileManager.Source.TrackingUrl do
  @moduledoc """
  Follows a tracking url to get the final url.
  """

  def get(urls) do
    urls
    |> get_final_url()
  end

  defp get_final_url(url) do
    http_client()
    |> Tesla.head(url)
  end

  defp http_client do
    middleware = [
      {Tesla.Middleware.Headers, [{"User-Agent", "Vind/#{Shared.version()}"}]},
      Tesla.Middleware.FollowRedirects
    ]

    Tesla.client(middleware, {Tesla.Adapter.Hackney, [recv_timeout: 30_000]})
  end
end
