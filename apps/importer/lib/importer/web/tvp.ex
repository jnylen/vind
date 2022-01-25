defmodule Importer.Web.TVP do
  @moduledoc """
  Importer for TVP.
  """

  use Importer.Base.Periodic, type: "daily"
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
  def import_content(tuple, batch, _channel, %{body: body} = _data) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Warsaw")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  defp process(body) do
    body
    |> parse
    ~>> xpath(
      ~x"//prrecord"l,
      start_time:
        ~x".//REAL_DATE_TIME/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//RTITEL/text()"S |> transform_by(&Text.norm/1),
      series_title: ~x".//STITEL/text()"S |> transform_by(&Text.norm/1),
      content_full_title: ~x".//TITEL/text()"S |> transform_by(&Text.norm/1),
      original_title: ~x".//ORIG/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//EPG/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//TYP/text()"So |> transform_by(&Text.norm/1),
      production_year: ~x".//JAHR/text()"Io,
      episode_num: ~x".//TEIL/text()"Io
    )
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add org title parsing of episode data
  # TODO: Add credits
  # TODO: Add categories

  defp process_item(item) do
    %{
      start_time: item[:start_time],
      titles: item |> add_title(),
      descriptions: Text.convert_string(item[:content_description], "pl", "content"),
      episode: item[:episode_num],
      production_date: Text.year_to_date(item[:production_year])
    }
    |> append_categories(
      Translation.translate_category(
        "TVP",
        item[:genre]
      )
    )
    |> end_of_transmission?(item)
  end

  defp add_title(item) do
    cond do
      !is_nil(item[:content_title]) ->
        Text.convert_string(item[:content_title], "pl", "content")

      !is_nil(item[:series_title]) ->
        Text.convert_string(item[:series_title], "pl", "content")

      !is_nil(item[:content_full_title]) ->
        Text.convert_string(item[:content_full_title], "pl", "content")

      true ->
        []
    end
  end

  defp end_of_transmission?(airing, %{content_full_title: "Zakończenie dnia"}) do
    airing
    |> Map.put(:titles, "end-of-transmission")
  end

  defp end_of_transmission?(airing, _), do: airing

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%F %T", :strftime)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    [folder, end_tag] = channel.grabber_info |> String.split(":")
    [year, month, day] = date |> to_string() |> String.split("-")

    sprintf("http://www.tvp.pl/prasa%sxml_OMI/m%04d%02d%02d_%s.xml", [
      folder,
      year |> String.to_integer(),
      month |> String.to_integer(),
      day |> String.to_integer(),
      end_tag
    ])
  end
end
