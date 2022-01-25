defmodule FileManager.Source.Mailchimp do
  @url_regex ~r/(gallery\.mailchimp|mcusercontent)\.com\//i
  @file_regex ~r/\/files\//i

  @doc """
  Process urls grabbed from a body
  """
  def get(urls) do
    urls
    |> process_url()
  end

  # Process a url to the correct function
  defp process_url(url) do
    if Regex.match?(@url_regex, url) and Regex.match?(@file_regex, url) do
      url
    end
  end
end
