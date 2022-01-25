defmodule Importer.File.Eurosport do
  @moduledoc """
    Importer for Eurosport Channels
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
    if Regex.match?(~r/\.xml$/i, file_name) do
      # XML
      import_xml(file, channel)
    else
      {:error, "not a xml file"}
    end
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
      |> NewBatch.start_new_batch?(item, channel, "00:00", "GMT")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  def import_xml(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x".//BroadcastDate_GMT"l,
      start_date: ~x"./@Day"S,
      airings: [
        ~x".//Emission"l,
        start_time: ~x"./StartTimeGMT/text()"S,
        end_time: ~x"./EndTimeGMT/text()"S,
        content_title: ~x"./Title/text()"S |> transform_by(&Text.norm/1),
        content_description: ~x"./Description/text()"So |> transform_by(&Text.norm/1),
        genre: ~x"./Sport/text()"So |> transform_by(&Text.norm/1),
        special_type: ~x"./BroadcastType/text()"So |> transform_by(&Text.norm/1),
        is_hd: ~x"./HD/text()"So |> Text.transform_to_boolean(),
        has_catchup: ~x"./CATCHUP/text()"So |> Text.transform_to_boolean(),
        bline: ~x"./Feature/text()"So,
        image: ~x"./ImageHD/text()"So |> transform_to_image_struct()
      ]
    )
    |> Okay.flat_map(&process_day(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Process days
  defp process_day(day, channel) do
    day.airings
    |> Okay.map(&process_item(&1, day.start_date, channel))
    |> Okay.reject(&is_nil/1)
  end

  # TODO: Parse titles for sport event data
  # TODO: Add qualifiers

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item, date, channel) do
    %{
      start_time: parse_datetime(date, item[:start_time]),
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
      images: [item[:image]]
    }
    |> append_categories(
      Translation.translate_category(
        "Eurosport",
        item[:genre]
      )
    )
    |> add_qualifiers("hd", item[:is_hd])
    |> add_qualifiers("catchup", item[:has_catchup])
    |> add_qualifiers("type", (Map.get(item, :special_type, "") || "") |> String.downcase())
  end

  defp add_qualifiers(airing, "hd", true) do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["HD"]))
  end

  defp add_qualifiers(airing, "catchup", true) do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["catchup"]))
  end

  defp add_qualifiers(airing, "type", "direkt") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["live"]))
  end

  defp add_qualifiers(airing, "type", "direkte") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["live"]))
  end

  defp add_qualifiers(airing, "type", "live") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["live"]))
  end

  defp add_qualifiers(airing, "type", "suora lähetys") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["live"]))
  end

  defp add_qualifiers(airing, "type", "repris") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["rerun"]))
  end

  defp add_qualifiers(airing, "type", "reprise") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["rerun"]))
  end

  defp add_qualifiers(airing, "type", "replay") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["rerun"]))
  end

  defp add_qualifiers(airing, "type", "genudsendelse") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["rerun"]))
  end

  defp add_qualifiers(airing, "type", "uusinta") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["rerun"]))
  end

  defp add_qualifiers(airing, _, _), do: airing

  defp transform_to_image_struct(arg), do: SweetXml.transform_by(arg, &to_image_struct/1)

  defp to_image_struct(nil), do: nil

  defp to_image_struct(string),
    do: %ImageManager.Image{
      source: string,
      type: "content",
      copyright: "Eurosport SAS"
    }

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%0d/%0m/%Y %H:%M", :strftime)
  end
end
