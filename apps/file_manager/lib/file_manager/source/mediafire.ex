# https://www.mediafire.com/api/1.4/folder/get_content.php?content_type=files&filter=all&order_by=name&order_direction=asc&chunk=1&version=1.5&folder_key=vwm2y8iyts6d1&response_format=json
# https://stackoverflow.com/questions/4640176/get-direct-download-link-and-file-site-from-mediafire-com

defmodule FileManager.Source.Mediafire do
  alias FileManager.Helper.URL, as: URLHelper
  alias Shared.HttpClient

  @moduledoc """
  Grabs direct urls for files inside of a Mediafire folder and/or download page.
  """

  @file_regex ~r/mediafire\.com\/file\//i
  @file_download_url_regex ~r/"http(|s):\/\/download(?<download_url>.*)"/i
  @folder_regex ~r/mediafire\.com\/folder\//i
  @folder_id_regex ~r/\/folder\/(?<id>.*?)\//i

  @doc """
  Process urls grabbed from a body
  """
  def get(urls) do
    urls
    |> process_url()
  end

  # Process a url to the correct function
  defp process_url(url) do
    {:ok, jar} = CookieJar.new()

    result =
      cond do
        Regex.match?(@file_regex, url) -> get_file(url, jar)
        Regex.match?(@folder_regex, url) -> get_folder(url, jar)
        true -> nil
      end

    CookieJar.stop(jar)

    result
  end

  # Get files in a folder
  defp get_folder(url, jar) do
    # Get API content
    # Get files
    # Send to get_file
    # Return contents

    @folder_id_regex
    |> Regex.named_captures(url)
    |> case do
      %{"id" => folder_id} ->
        folder_id
        |> actually_get_folder(jar)
        |> Enum.concat(
          folder_id
          |> actually_get_folder(jar, "folder")
        )

      _ ->
        nil
    end
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  defp actually_get_folder(folder_id, jar, content_type \\ "files") do
    folder_id
    |> folder_page_url(content_type)
    |> get_http(jar)
    |> parse_folder_page_body(jar)
  end

  # Get a single file
  defp get_file(url, jar) do
    url
    |> get_http(jar)
    |> parse_file_page_body()
    |> URLHelper.parse_url()
  end

  defp folder_page_url(id, content_type \\ "files") do
    URI.to_string(
      URI.parse("https://www.mediafire.com/api/1.4/folder/get_content.php")
      |> Map.put(
        :query,
        %{
          "chunk" => "1",
          "content_type" => content_type,
          "filter" => "all",
          "order_by" => "name",
          "order_direction" => "asc",
          "response_format" => "json",
          "version" => "1.5",
          "folder_key" => id
        }
        |> URI.encode_query()
      )
    )
  end

  defp get_http(url, jar) do
    HttpClient.init(%{cookie_jar: jar})
    |> HttpClient.get(url)
  end

  defp parse_file_page_body({_client, %{body: body}}) do
    @file_download_url_regex
    |> Regex.named_captures(body)
    |> case do
      %{"download_url" => url} -> "http://download" <> url
      _ -> nil
    end
  end

  defp parse_file_page_body(_), do: nil

  # Parse a json
  def parse_folder_page_body({_client, %{body: body}}, jar) do
    body
    |> Jsonrs.decode()
    |> case do
      {:ok, %{"response" => %{"folder_content" => %{"files" => files}}}} ->
        files
        |> Enum.map(fn file ->
          file
          |> Map.get("links")
          |> Map.get("normal_download")
          |> get_file(jar)
        end)

      {:ok, %{"response" => %{"folder_content" => %{"folders" => folders}}}} ->
        folders
        |> Enum.map(fn folder ->
          folder
          |> Map.get("folderkey")
          |> folder_page_url()
          |> get_http(jar)
          |> parse_folder_page_body(jar)
        end)

      _ ->
        nil
    end
  end

  def parse_folder_page_body(_, _), do: nil
end
