defmodule Importer.Web.VRTRadio do
  @moduledoc """
  Importer for VRT Radio
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body}) do
    body
    |> process(batch)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Brussels")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item)
    )
  end

  defp process(body, batch) do
    body
    |> parse()
    ~>> xpath(
      ~x"//broadcast"l,
      start_time: ~x".//starttime/text()"S,
      end_time: ~x".//endtime/text()"S,
      content_title: ~x".//title/text()"S
    )
    |> Okay.map(&process_item(&1, batch))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add qualifiers etc
  defp process_item(item, batch) do
    %{
      start_time: item[:start_time] |> parse_datetime(),
      end_time: item[:end_time] |> parse_datetime(),
      titles:
        Text.convert_string(
          item[:content_title] |> Text.norm(),
          "de",
          "content"
        )
    }
  end

  defp parse_datetime(date_time) do
    date_time
    |> DateTimeParser.parse_datetime!()
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    "http://epg-xml.vrt.be/#{parse_aws(channel.grabber_info)}"
  end

  defp parse_aws(grabber_info) do
    Shared.HttpClient.init()
    |> Shared.HttpClient.get("http://epg-xml.vrt.be/?max-keys=2147483647&prefix=#{grabber_info}")
    ~>> Map.get(:body)
    |> parse()
    ~>> xpath(
      ~x"//Contents"l,
      file_name: ~x".//Key/text()"S
    )
    |> Enum.sort_by(fn item ->
      item.file_name
    end)
    |> List.last()
    |> Map.get(:file_name)
  end
end
