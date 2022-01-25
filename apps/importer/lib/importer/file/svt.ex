defmodule Importer.File.Svt do
  @moduledoc """
  Importer for SVT Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser
  alias Importer.Parser.PublicSchedule, as: Parser

  require OK
  use OK.Pipe

  # Channels by SVT
  # @channels %{
  #   "se.svt.channel.24" => "svt24.svt.se",
  #   "se.svt.channel.SVT1" => "svt1.svt.se",
  #   "se.svt.channel.SVT2" => "svt2.svt.se",
  #   "se.svt.channel.SVTB" => "svtb.svt.se",
  #   "se.svt.channel.SVTK" => "kunskapskanalen.svt.se"
  # }

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    file
    |> process(channel)
    |> start_batch(channel, parse_filename(file_name, channel))
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    batch_name
    |> NewBatch.start_batch(channel, "UTC")
    |> process_items(items, channel)
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> process_item()
        |> Parser.remove_custom_fields()
      ),
      items,
      channel
    )
  end

  defp process(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> stream_file!()
      |> Parser.parse(channel)
    else
      {:error, "file does not exist"}
    end
  end

  # Parse shit from the descriptions
  defp process_item(item) do
    {_, new_item} =
      item
      |> Map.get(:descriptions, [])
      |> Enum.map(& &1.value)
      |> Enum.map_reduce(item |> Map.delete(:descriptions), fn x, acc ->
        {nil, acc |> parse_description(x)}
      end)

    new_item
    |> Map.delete(:images)
    |> is_movie?(Map.get(item, "c_treenodes", []))
  end

  # Movie?
  defp is_movie?(airing, trees) do
    if Enum.member?(trees, "Film") do
      airing
      |> Map.put(:episode, nil)
      |> Map.put(:season, nil)
      |> Map.put(:program_type, "movie")
    else
      airing
    end
  end

  defp parse_description(airing, desc) do
    results =
      desc
      |> TextParser.split_text()
      |> Okay.map(fn string ->
        case description_regex(string) do
          {:error, _} -> {string, %{}}
          {:ok, result} -> {nil, result}
        end
      end)

    desc =
      results
      |> Okay.map(fn {string, _} ->
        string
      end)
      |> TextParser.join_text()
      |> Text.convert_string("sv", "content")

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:credits, parse_credits(result["actors"], "actor"))
          |> TextParser.put_non_nil(:credits, parse_credits(result["directors"], "director"))
          |> TextParser.put_non_nil(:credits, parse_credits(result["presenters"], "presenter"))
          |> TextParser.put_non_nil(:episode, Text.to_integer(result["episode_num"]))
          |> TextParser.put_non_nil(:season, Text.to_integer(result["season_num"]))
          |> TextParser.put_non_nil(:qualifiers, result["qualifiers"])
          |> TextParser.put_non_nil(
            :titles,
            Text.convert_string(
              result["original_title"] |> Text.norm(),
              Text.detect_language(result["original_title"] |> Text.norm()),
              "original"
            )
          )
          |> TextParser.put_non_nil(
            :subtitles,
            Text.convert_string(
              result["subtitle"] |> Text.norm(),
              Text.detect_language(result["subtitle"] |> Text.norm()),
              "content"
            )
          )

        {result, TextParser.merge_with_lists(acc, new_result)}
      end)

    airing
    |> Map.put(:descriptions, desc)
    |> TextParser.merge_with_lists(result)
  end

  # Adds the needed regexps and matches the string
  defp description_regex(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/^\((?<original_title>.*)\)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Säsong (?<season_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Del (?<episode_num>\d+) av (?<of_episode_num>\d+)\: (?<subtitle>.*)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Del (?<episode_num>\d+) av (?<of_episode_num>\d+)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^I rollerna: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/från (?<production_year>\d\d\d\d)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Regi: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Övriga medverkande: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Medverkande: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Programledare: (?<presenters>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^HD\.$/i,
      %{"qualifiers" => ["HD"]}
    )
    |> StringMatcher.add_regexp(
      ~r/^Sänds med 5\.1 ljud\.$/i,
      %{"qualifiers" => ["DD 5.1"]}
    )
    |> StringMatcher.match_captures(string)
  end

  defp parse_credits("", _), do: []
  defp parse_credits(nil, _), do: []

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(~r/(, | og )/i)
    |> Okay.map(fn person ->
      %{
        person:
          person
          |> Text.norm()
          |> String.replace(~r/m\.fl\.$/, "")
          |> String.replace(~r/\.$/, "")
          |> Text.norm(),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  # Parse the filename
  # Returns a string of datetime
  defp parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/_(?<year>[0-9]{4}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)_/i,
           Path.basename(filename)
         ) do
      %{"month" => month, "day" => day, "year" => year} ->
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
