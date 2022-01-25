defmodule Importer.File.PPS do
  @moduledoc """
  Importer for Disney Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Shared.Zip

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    require Logger

    if Regex.match?(~r/\.xml$/i, file_name) do
      import_xml(file, channel)
      |> OK.wrap()
      |> start_batch(channel, parse_filename(file_name, channel))
      |> NewBatch.end_batch()
    else
      {:error, "not a zip file"}
    end
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    NewBatch.start_batch(batch_name, channel, "Europe/Berlin")
    |> process_items(items, channel)
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp import_xml(file_name, channel) do
    file_name
    |> read_file!()
    |> :unicode.characters_to_binary(:latin1)
    |> Okay.replace("iso-8859-1", "utf-8")
    |> Okay.replace("<!DOCTYPE listing SYSTEM \"./listing.dtd\">", "")
    |> parse()
    ~>> xpath(
      ~x"//broadcast"l,
      start_time: ~x".//time/text()"S |> transform_by(&parse_datetime/1),
      content_title: ~x".//title/text()"S |> transform_by(&Text.norm/1),
      content_subtitle: ~x".//subtitle/text()"So |> transform_by(&Text.norm/1),
      content_description: ~x".//text/text()"So |> transform_by(&Text.norm/1),
      original_title: ~x".//origtitle/text()"So |> transform_by(&Text.norm/1),
      original_subtitle: ~x".//origsubtitle/text()"So |> transform_by(&Text.norm/1),
      season_num: ~x".//season/text()"Io,
      episode_num: ~x".//number/text()"Io,
      genre: ~x".//kind/text()"So |> transform_by(&Text.norm/1),
      stereo: ~x".//stereo/text()"So |> transform_by(&Text.norm/1),
      is_ws: ~x".//wscreen/text()"So |> transform_by(&Text.norm/1),
      is_hd: ~x".//hdtv/text()"So |> transform_by(&Text.norm/1),
      is_dolbydig: ~x".//dolbydig/text()"So |> transform_by(&Text.norm/1),
      directors: ~x".//director/text()"So |> transform_by(&Text.norm/1),
      cast: [
        ~x".//actor"lo,
        name: ~x".//actorname/text()"S |> transform_by(&Text.norm/1),
        role: ~x".//role/text()"S |> transform_by(&Text.norm/1)
      ]
    )
    |> Okay.map(&process_item(&1, channel))
    |> Okay.flatten()
    |> Okay.reject(&is_nil/1)
  end

  defp process_item(program, _channel) do
    %{
      start_time: program.start_time,
      titles:
        Text.convert_string(
          program.content_title,
          "de",
          "content"
        ) ++
          Text.convert_string(
            program.original_title,
            "en",
            "original"
          ),
      subtitles:
        Text.convert_string(
          program.content_subtitle,
          "de",
          "content"
        ) ++
          Text.convert_string(
            program.original_subtitle,
            "en",
            "original"
          ),
      descriptions:
        Text.convert_string(
          program.content_description,
          "de",
          "content"
        ),
      episode: program.episode_num,
      season: program.season_num
    }
    |> add_credits(parse_credits(program[:cast], "actor"))
    |> add_credits(parse_credits(program[:directors], "director"))
    |> add_qualifiers(:hd, program[:is_hd])
    |> add_qualifiers(:ws, program[:is_ws])
  end

  defp add_qualifiers(airing, :hd, "hdtv") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["HD"]))
  end

  defp add_qualifiers(airing, :ws, "16:9") do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["widescreen"]))
  end

  # defp add_qualifiers(airing, :dolby, "dbdig") do
  #   airing
  #   |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["DD 5.1"]))
  # end

  # defp add_qualifiers(airing, :stereo, "st") do
  #   airing
  #   |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["stereo"]))
  # end

  defp add_qualifiers(airing, _, _), do: airing

  defp parse_credits(list, "actor") do
    list
    |> Enum.map(fn actor ->
      %{
        person: Text.norm(actor.name),
        role: Text.norm(actor.role),
        type: "actor"
      }
    end)
  end

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(", ")
    |> Okay.map(fn person ->
      %{
        person: Text.norm(person),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  # Add credits
  defp add_credits(%{} = airing, list) when is_list(list) do
    airing
    |> Map.put(:credits, (Map.get(airing, :credits) || []) ++ list)
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%F %T", :strftime)
  end

  @doc """
  Parse the batch_name from the file_name
  """
  def parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/_(?<year>[0-9]{4}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)/i,
           Path.basename(filename)
         ) do
      %{"year" => year, "month" => month, "day" => day} ->
        # "#{year}-#{month}-#{day}"
        sprintf("%s_%04d-%02d-%02d", [
          channel.xmltv_id,
          String.to_integer(year),
          String.to_integer(month),
          String.to_integer(day)
        ])

      _ ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end
end
