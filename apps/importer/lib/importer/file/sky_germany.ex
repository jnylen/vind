defmodule Importer.File.SkyGermany do
  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper
  alias Importer.Parser.SkyGermanyCSV, as: Parser

  require OK

  @fields %{
    "service" => 1,
    "start_time" => 3,
    "end_time" => 5,
    "content_title" => 9,
    "content_subtitle" => 10,
    "original_title" => 11,
    "original_subtitle" => 12,
    "length" => 14,
    "production_year" => 15,
    "production_country" => 16,
    "black_white" => 17,
    "audio_format" => 18,
    "video_format" => 19,
    # main
    "genre_1" => 21,
    # magazine
    "genre_2" => 22,
    "is_movie" => 26,
    "credits" => 30,
    "content_description" => 35,
    "magazine_description" => 50,
    "is_hd" => 70,
    "is_live" => 74,
    "is_3d" => 76,
    "episode" => 78,
    "season" => 79,
    "is_uhd" => 82,
    "is_uhdhdr" => 83
  }

  @moduledoc """
  Importer for channels aired by Sky Deutschland.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    file
    |> process_file(channel)
    |> start_batch(channel, parse_filename(file_name, channel))
  end

  @doc """
  List all channels in a CSV file
  """
  def list_channels(file_name) do
    file_name
    |> stream_file!()
    |> Parser.parse_stream()
    |> Okay.map(&Enum.at(&1, @fields["service"]))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&IO.inspect/1)

    []
  end

  defp start_batch(_, _, {:error, reason}), do: {:error, reason}
  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    batch_name
    |> NewBatch.start_batch(channel, "Europe/Berlin")
    |> process_batch_items(items, channel)
  end

  defp process_batch_items(tuple, [], _), do: tuple

  defp process_batch_items(tuple, [item | items], channel) do
    process_batch_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process_file(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> stream_file!()
      |> Parser.parse_stream()
      |> Okay.reject(fn airing ->
        airing |> Enum.at(Map.get(@fields, "service", "")) |> String.trim() |> String.downcase() !=
          channel.grabber_info |> String.trim() |> String.downcase()
      end)
      |> Okay.map(&process_item(&1, channel))
      |> Helper.sort_by_start_time()
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp process_item(airing, channel) do
    %{
      start_time: parse_datetime(Enum.at(airing, @fields["start_time"]))
    }
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        airing |> Enum.at(@fields["content_title"]) |> Text.norm(),
        List.first(channel.schedule_languages),
        "content"
      )
    )
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        airing |> Enum.at(@fields["original_title"]) |> Text.norm(),
        nil,
        "original"
      )
    )
    |> Helper.merge_list(
      :subtitles,
      Text.string_to_map(
        airing |> Enum.at(@fields["content_subtitle"]) |> Text.norm(),
        List.first(channel.schedule_languages),
        "content"
      )
    )
    |> Helper.merge_list(
      :subtitles,
      Text.string_to_map(
        airing |> Enum.at(@fields["original_subtitle"]) |> Text.norm(),
        nil,
        "original"
      )
    )
    |> Helper.merge_list(
      :descriptions,
      Text.string_to_map(
        airing |> Enum.at(@fields["content_description"]) |> Text.norm() |> cleanup_desc(),
        List.first(channel.schedule_languages),
        "content"
      )
    )
    |> parse_credits(airing |> Enum.at(@fields["credits"]))
    |> append_categories(
      Translation.translate_category(
        "SkyDE",
        airing |> Enum.at(@fields["genre_2"]) |> Text.norm()
      )
    )
    |> add_movie_type(airing |> Enum.at(@fields["is_movie"]) |> Text.to_boolean())
    |> Map.put(:episode, airing |> Enum.at(@fields["episode"]) |> Text.to_integer())
    |> Map.put(:season, airing |> Enum.at(@fields["season"]) |> Text.to_integer())
    |> add_qualifiers("hd", airing |> Enum.at(@fields["is_hd"]) |> Text.to_boolean())
    |> add_qualifiers("uhd", airing |> Enum.at(@fields["is_uhd"]) |> Text.to_boolean())
    |> add_qualifiers("live", airing |> Enum.at(@fields["is_live"]) |> Text.to_boolean())
    |> add_qualifiers("3d", airing |> Enum.at(@fields["is_3d"]) |> Text.to_boolean())
    |> add_qualifiers("video", airing |> Enum.at(@fields["video_format"]))
    |> add_qualifiers("audio", airing |> Enum.at(@fields["audio_format"]))
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(dt) do
    case DateTimeParser.parse_datetime(dt, to_utc: true) do
      {:ok, val} -> val
      _ -> nil
    end
  end

  # Remove episode info from a desc
  defp cleanup_desc(nil), do: nil
  defp cleanup_desc(""), do: nil

  defp cleanup_desc(desc) do
    desc
    |> String.replace(~r/^(\d+)\. Staffel, Folge (\d+)\:/iu, "")
    |> String.trim()
  end

  # Tag a programme as a movie
  defp add_movie_type(airing, true), do: airing |> Map.put(:program_type, "movie")
  defp add_movie_type(airing, _), do: airing

  # Add qualifiers
  defp add_qualifiers(airing, "hd", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "HD"
    )
  end

  defp add_qualifiers(airing, "3d", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "3D"
    )
  end

  defp add_qualifiers(airing, "uhd", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "UHD"
    )
  end

  defp add_qualifiers(airing, "live", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "live"
    )
  end

  defp add_qualifiers(airing, "video", "16:9") do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "widescreen"
    )
  end

  defp add_qualifiers(airing, "video", "4:3") do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "smallscreen"
    )
  end

  defp add_qualifiers(airing, "audio", "Dolby Surround") do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "surround"
    )
  end

  defp add_qualifiers(airing, _, _), do: airing

  # Parse Sky's weird credit list
  defp parse_credits(airing, credits) do
    credits
    |> String.split("}{")
    |> parse_credit()
    |> Enum.reject(&is_nil/1)
    |> add_credits(airing)
  end

  # Merge the credits into the airing
  defp add_credits(credits, airing) do
    airing
    |> Helper.merge_list(
      :credits,
      credits
    )
  end

  # Parse a single credit
  defp parse_credit([]), do: []

  defp parse_credit([credit | credits]) do
    [
      credit
      |> String.replace("{", "")
      |> String.replace("}", "")
      |> String.split(";")
      |> credit_into_map
      | parse_credit(credits)
    ]
  end

  # Turn it into the correct map
  defp credit_into_map([role, last_name, first_name, "N", _, _, "DA"]) do
    %{
      type: "actor",
      person:
        Enum.join(
          [first_name |> Text.norm(), last_name |> Text.norm()],
          " "
        ),
      role: role |> Text.norm()
    }
  end

  defp credit_into_map([_, last_name, first_name, "N", _, _, "RE"]) do
    %{
      type: "director",
      person:
        Enum.join(
          [first_name |> Text.norm(), last_name |> Text.norm()],
          " "
        )
    }
  end

  defp credit_into_map(_), do: nil

  # Parse the batch_name from the file_name
  defp parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/(?<week>[0-9]{2}?)_(?<year>[0-9]{4}?)/i,
           Path.basename(filename)
         ) do
      %{"year" => year, "week" => week} ->
        # "#{year}-#{month}-#{day}"
        sprintf("%s_%04d-%02d", [
          channel.xmltv_id,
          String.to_integer(year),
          String.to_integer(week)
        ])

      _ ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end
end
