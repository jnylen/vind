defmodule FileManager.Helper.URL do
  @doc """
  Parse file_name etc from the url
  """
  def parse_url(nil), do: nil
  def parse_url([]), do: nil

  def parse_url(url) when is_bitstring(url) do
    %{
      "name" => url |> Path.basename() |> URI.decode(),
      "url" => url
    }
  end

  def parse_url(urls) when is_list(urls) do
    urls
    |> Enum.map(&parse_url/1)
  end
end
