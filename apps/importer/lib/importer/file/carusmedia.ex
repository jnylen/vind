defmodule Importer.File.Carusmedia do
  @moduledoc """
    Importer for former Carusmedia channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    process(file, channel)
    |> start_batch(channel)
  end

  defp start_batch({:error, reason}, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel) do
    NewBatch.dummy_batch()
    |> process_items(items, channel)
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  def process(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x".//programmElement"l,
      start_date: ~x"./header/kdatum/text()"S,
      start_time: ~x"./header/szeit/text()"S,
      content_description: ~x"./kurzInhalt/text()"So |> transform_by(&Text.norm/1),
      content_subtitle: ~x"./header/epistitel/text()"S |> transform_by(&Text.norm/1),
      content_title: ~x"./header/stitel/text()"S |> transform_by(&Text.norm/1),
      genre: ~x"./header/pressegenre/text()"S |> transform_by(&Text.norm/1),
      episode_num: ~x"./header/folgennummer/text()"Io,
      production_countries: ~x"./header/produktionsland/text()"S |> transform_by(&Text.norm/1),
      images: [
        ~x"//bild"l,
        source: ~x"./@datei"So
      ]
    )
    |> Okay.map(&process_program(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_program(item, channel) do
    %{
      start_time: parse_datetime(item.start_date, item.start_time),
      titles:
        Text.convert_string(
          item[:content_title],
          List.first(channel.schedule_languages),
          "content"
        ),
      descriptions:
        Text.convert_string(
          item[:content_description],
          List.first(channel.schedule_languages),
          "content"
        ),
      episode: item[:episode_num],
      images:
        Enum.map(item[:images], fn data ->
          struct(ImageManager.Image, Map.put(data, :type, "content"))
        end)
    }
    |> append_categories(Translation.translate_category("Carusmedia", item[:genre]))
    |> append_countries(Translation.translate_country("Carusmedia", item[:production_countries]))
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%F %H:%M:%S", :strftime)
    |> Timex.to_datetime("Europe/Berlin")
    |> Timex.Timezone.convert("UTC")
  end
end
