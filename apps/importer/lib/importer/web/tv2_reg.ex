defmodule Importer.Web.TV2Reg do
  @moduledoc """
  Importer for TV2 Regional channels.
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

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
  def import_content(tuple, _batch, _channel, %{body: body} = _data) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone("UTC")
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

  defp process(body) do
    body
    |> parse
    ~>> xpath(
      ~x"//item"l,
      start_time:
        ~x".//pubDate/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//title/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//description/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//tv2r:kategori/text()"So |> transform_by(&Text.norm/1)
    )
    |> Enum.map(&process_item(&1))
    |> Enum.reject(&is_nil/1)
    |> Importer.Parser.Helper.sort_by_start_time()
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add genre
  # FIXME: Error adding shows for this channel, skipping program start in aug.
  defp process_item(item) do
    %{
      start_time: item[:start_time],
      titles: Text.convert_string(item[:content_title], "da", "content"),
      descriptions: Text.convert_string(item[:content_description], "da", "content")
    }
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(string) do
    [_, datetime_string] = string |> String.split(",")

    datetime_string
    |> DateTimeParser.parse_datetime!(to_utc: true)
    |> case do
      %NaiveDateTime{} = dt ->
        dt
        |> Timex.to_datetime("Europe/Copenhagen")

      dt ->
        dt
    end
    |> Timex.Timezone.convert("UTC")
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, channel) do
    import ExPrintf

    sprintf("%s/program_%s.xml", [config.url_root, channel.grabber_info])
  end
end
