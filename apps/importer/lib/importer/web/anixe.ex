defmodule Importer.Web.Anixe do
  @moduledoc """
  Importer for Anixe Germany
  """

  use Importer.Base.Periodic, type: "daily"

  alias Importer.Helpers.Image
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Text

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body} = _data) do
    body
    |> process(
      tuple
      |> NewBatch.set_timezone("Europe/Berlin")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process(body, tuple) do
    body
    |> parse
    ~>> xpath(
      ~x"//CLIP"l,
      start_time:
        ~x".//DATE/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//TITEL/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//INFO/text()"S |> transform_by(&Text.norm/1),
      content_image: ~x".//BILD/text()"S |> transform_by(&Text.norm/1)
    )
    |> process_items(tuple)
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items([], tuple), do: tuple

  defp process_items([item | items], tuple) do
    process_items(
      items,
      tuple
      |> NewBatch.add_airing(%{
        start_time: item[:start_time],
        titles: Text.convert_string(item[:content_title], "de", "content"),
        descriptions: Text.convert_string(item[:content_description], "de", "content"),
        images: [
          %ImageManager.Image{
            source: item[:content_image],
            type: "content",
            copyright: "ANIXE HD TELEVISION GmbH & Co KG"
          }
        ]
      })
    )
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%F %H:%M:%S", :strftime)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, _channel) do
    import ExPrintf

    sprintf("%s?wann=%s", [
      config.url_root,
      date |> to_string()
    ])
  end
end
