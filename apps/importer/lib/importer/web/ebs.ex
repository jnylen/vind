defmodule Importer.Web.EBS do
  @moduledoc """
  Importer for EBS-provided EPG Data.
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
    |> batch_em(tuple)
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

  def process(body) do
    body
    # |> String.replace(~r/<!--(.*)-->/, "")
    |> parse
    ~>> xpath(
      ~x"//event"l,
      start_time: ~x".//start/text()"S,
      end_time: ~x".//end/text()"S,
      start_date: ~x".//txDay/text()"S,
      content_title: ~x".//title/text()"S |> transform_by(&Text.norm/1),
      series_description: ~x".//programmeEPGSynopsis/text()"S |> transform_by(&Text.norm/1),
      episode_description: ~x".//episodeEPGSynopsis/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//Genre/text()"So |> transform_by(&Text.norm/1),
      content_image: ~x".//programmeImage/text()"lSo,
      series_image: ~x".//seriesImage/text()"So,
      episode_image: ~x".//episodeImage/text()"So,
      production_year: ~x".//year/text()"Io,
      season_num: ~x".//Series/text()"Io,
      episode_num: ~x".//EpisodeNum/text()"Io,
      episode_title: ~x".//EpisodeTitle/text()"S |> transform_by(&Text.norm/1),
      of_episode: ~x".//EpsInSeries/text()"Io
    )
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add cast
  defp process_item(item) do
    %{
      start_time: parse_datetime(item[:start_date], item[:start_time]),
      titles: Text.convert_string(item[:content_title], "en", "content"),
      descriptions:
        Text.convert_string(item[:content_description], "en", "content") ++
          Text.convert_string(item[:series_description], "en", "series"),
      subtitles: Text.convert_string(item[:episode_title], "en", "content"),
      season: item[:season_num],
      episode: item[:episode_num],
      of_episode: item[:of_episode],
      production_date: Text.year_to_date(item[:production_year])
    }
    |> append_categories(
      Translation.translate_category(
        "EBS",
        item[:genre]
      )
    )
    |> append_images(item[:content_image])
  end

  defp append_images(airing, nil), do: airing
  defp append_images(airing, ""), do: airing
  defp append_images(airing, []), do: airing

  defp append_images(airing, urls) do
    urls
    |> Enum.reject(fn url -> String.match?(url, ~r/cropped/) end)
    |> Enum.reduce(airing, fn url, airing ->
      airing
      |> Importer.Parser.Helper.merge_list(
        :images,
        %ImageManager.Image{
          type: "content",
          source: url
        }
      )
    end)
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%Y-%0m-%0d %H:%M:%S", :strftime)
    |> Timex.to_datetime("UTC")

    # |> Timex.format!("{RFC3339z}")
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, channel) do
    import ExPrintf

    sprintf("%s/channel_%s/schedule.xml", [
      config.url_root,
      channel.grabber_info
    ])
  end
end
