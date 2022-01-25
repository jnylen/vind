defmodule Importer.Web.DK4 do
  @moduledoc """
  Importer for DK4.
  """

  use Importer.Base.Periodic, type: "one"
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
  def import_content(tuple, _batch, _channel, %{body: body} = _data) do
    body
    |> process()
    |> batch_em(
      tuple
      |> NewBatch.set_timezone("Europe/Copenhagen")
    )
  end

  defp batch_em({:error, reason}, _), do: {:error, reason}
  defp batch_em(_, {:error, reason}), do: {:error, reason}

  defp batch_em({:ok, []}, tuple), do: tuple

  defp batch_em({:ok, [item | items]}, tuple) do
    batch_em(
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
      ~x"//ProgramPunkt"l,
      start_time:
        ~x".//StartTid/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//Titel/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//Omtale1/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//Genre/text()"So |> transform_by(&Text.norm/1),
      production_year: ~x".//ProduktionsAar/text()"Io,
      episode_num: ~x".//EpisodeNr/text()"Io,
      episode_title: ~x".//EpisodeTitel/text()"S |> transform_by(&Text.norm/1),
      of_episode: ~x".//AntalEpisoder/text()"Io
    )
    |> Importer.Parser.Helper.sort_by_start_time()
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item) do
    %{
      start_time: item[:start_time],
      titles: Text.convert_string(item[:content_title], "da", "content"),
      descriptions: Text.convert_string(item[:content_description], "da", "content"),
      subtitles: Text.convert_string(item[:episode_title], "da", "content"),
      episode: item[:episode_num],
      of_episode: item[:of_episode],
      production_date: Text.year_to_date(item[:production_year])
    }
    |> append_categories(
      Translation.translate_category(
        "DK4",
        item[:genre]
      )
    )
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> String.replace("+02:00", "")
    |> String.replace("+01:00", "")
    |> String.replace("+0200", "")
    |> String.replace("+0100", "")
    |> Timex.parse!("{ISO:Extended}")
    |> Timex.to_datetime("UTC")
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, _channel), do: config.url_root
end
