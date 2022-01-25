defmodule Importer.Web.TV2NO do
  @moduledoc """
  Importer for TV2 Norway.
  """

  use Importer.Base.Periodic, type: "weekly"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Helpers.Xmltv

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
    |> process_items(tuple)
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
      ~x"//programme"l,
      start_time:
        ~x".//@start"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//title[1]/text()"S |> transform_by(&Text.norm/1),
      original_title: ~x".//title[2]/text()"S |> transform_by(&Text.norm/1),
      content_description:
        ~x".//review[@source=\"program_long_synopsis\"]/text()"S |> transform_by(&Text.norm/1),
      series_description:
        ~x".//review[@source=\"series_long_synopsis\"]/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//category/text()"So |> transform_by(&Text.norm/1),
      production_country: ~x".//country/text()"Slo,
      production_year: ~x".//date/text()"Io,
      xmltv_ns:
        ~x".//episode-num[@system=\"xmltv_ns\"]/text()"So |> transform_by(&Xmltv.parse_xmltv_ns/1),
      program_type: ~x".//episode-num[@system=\"dd_content\"]/text()"So,
      image_content: ~x".//episode-num[@system=\"dd_main-program-image\"]/text()"So,
      image_season: ~x".//episode-num[@system=\"dd_main-season-image\"]/text()"So
    )
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item) do
    %{
      start_time: item[:start_time],
      titles: Text.convert_string(item[:content_title], "nb", "content"),
      descriptions:
        Text.convert_string(item[:content_description], "da", "content") ++
          Text.convert_string(item[:series_description], "da", "series"),
      episode: item[:xmltv_ns][:episode],
      season: item[:xmltv_ns][:season],
      images:
        ([to_image_struct(item[:image_content], "content")] ++
           [to_image_struct(item[:image_season], "season")])
        |> Enum.reject(&is_nil/1)
    }
    |> append_categories(
      Translation.translate_category(
        "TV2NO_type",
        item[:program_type]
      )
    )
    |> append_categories(
      Translation.translate_category(
        "TV2NO_genres",
        item[:genre]
      )
    )
    |> append_countries(
      Translation.translate_country(
        "TV2NO",
        item[:production_country]
      )
    )
    |> add_production_year(item[:production_year])
  end

  defp add_production_year(airing, nil), do: airing

  defp add_production_year(airing, production_year) do
    airing
    |> Map.put(:production_date, Text.year_to_date(production_year))
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%FT%H:%M:%S.%L%:z", :strftime)
    |> Timex.to_datetime("UTC")

    # |> Timex.format!("{RFC3339z}")
  end

  defp to_image_struct(nil, _), do: nil
  defp to_image_struct("", _), do: nil

  defp to_image_struct(string, type),
    do: %ImageManager.Image{
      source: string,
      type: type
    }

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    [_, week] = date |> to_string() |> String.split("-")

    sprintf("%s/%d/%02d", [
      config.url_root,
      channel.grabber_info |> String.to_integer(),
      week |> String.to_integer()
    ])
  end
end
