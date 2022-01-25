defmodule Importer.Web.HBOAdria do
  @moduledoc """
  Importer for HBO HR and SI
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
  def import_content(tuple, batch, channel, %{body: body}) do
    body
    |> process(channel)
    |> process_items(
      tuple
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

  ## TODO: ADD EPISODE PARSING
  defp process(body, channel) do
    body
    |> parse
    ~>> xpath(
      ~x"//item"l,
      start_time:
        ~x".//start_time_full/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//title/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//lead/text()"S |> transform_by(&Text.norm/1),
      category: ~x".//content_type/text()"S,
      primary_genre: ~x".//primary_genre/text()"S,
      secondary_genre: ~x".//secondary_genre/text()"S,
      imdb_id: ~x".//@imdb_id"S,
      image: ~x".//thnImage/text()"So
    )
    |> Okay.map(&process_item(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item, channel) do
    %{
      start_time: item[:start_time],
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
      images: [to_image_struct(item[:image])]
    }
    |> append_categories(
      Translation.translate_category(
        "HBOAdria_category",
        item[:category]
      )
    )
    |> append_categories(
      Translation.translate_category(
        "HBOAdria_genre",
        item[:primary_genre]
      )
    )
    |> add_imdb_id(item[:imdb_id])
  end

  defp add_imdb_id(airing, nil), do: airing
  defp add_imdb_id(airing, ""), do: airing

  defp add_imdb_id(airing, imdb_id) do
    airing
    |> Map.put(:metadata, [%{type: "imdb", value: "tt#{imdb_id}"}])
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%Y-%0m-%0d %H:%M:%S", :strftime)
    |> Timex.to_datetime("Europe/Zagreb")
    |> Timex.Timezone.convert("UTC")
  end

  defp to_image_struct(nil), do: nil
  defp to_image_struct(""), do: nil

  defp to_image_struct(string),
    do: %ImageManager.Image{
      source: String.replace(string, "_-_960", ""),
      type: "content"
    }

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    [tld, cid] = channel.grabber_info |> String.split(";")

    sprintf("https://www.hbo.%s/schedule/xml?date=%s&channel=%s", [tld, date |> to_string(), cid])
  end
end
