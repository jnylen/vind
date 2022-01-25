defmodule Importer.File.Venetsia do
  @moduledoc """
  Importer for Venetsia Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser

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
    |> start_batch(channel, parse_filename(file_name, channel))
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    NewBatch.start_batch(batch_name, channel, "UTC")
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

  defp process(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> read_file!()
      |> parse
      ~>> xpath(
        ~x"//ProgramItem"l,
        start_time:
          ~x".//ProgramInformation/tva:ProgramDescription/tva:ProgramLocationTable/tva:BroadcastEvent/tva:PublishedStartTime/text()"S
          |> transform_by(&parse_datetime/1),
        end_time:
          ~x".//ProgramInformation/tva:ProgramDescription/tva:ProgramLocationTable/tva:BroadcastEvent/tva:PublishedEndTime/text()"S
          |> transform_by(&parse_datetime/1),
        content_title: [
          ~x".//ProgramInformation/tva:ProgramDescription/tva:ProgramInformation/tva:BasicDescription/tva:Title",
          value: ~x"./text()"S |> transform_by(&Text.norm/1),
          language: ~x"./@xml:lang"S |> transform_by(&Text.norm/1)
        ],
        content_description: [
          ~x".//ProgramInformation/tva:ProgramDescription/tva:ProgramInformation/tva:BasicDescription/tva:Synopsis",
          value: ~x"./text()"S |> transform_by(&Text.norm/1),
          language: ~x"./@xml:lang"S |> transform_by(&Text.norm/1)
        ],
        genre:
          ~x".//ProgramInformation/tva:ProgramDescription/tva:ProgramInformation/tva:BasicDescription/tva:Genre/text()"Io
      )
      |> Okay.map(&process_item(&1, channel))
      |> Okay.flatten()
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp process_item(program, _channel) do
    %{
      start_time: program.start_time,
      # end_time: program.end_time,
      titles:
        Text.convert_string(
          program.content_title.value |> clean_title(),
          program.content_title.language,
          "content"
        )
    }
    |> parse_description(program.content_description)
  end

  def parse_description(airing, nil), do: airing
  def parse_description(airing, []), do: airing

  def parse_description(airing, [desc | descs]),
    do:
      airing
      |> parse_description(desc)
      |> parse_description(descs)

  def parse_description(airing, %{value: desc, language: language}) do
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
      |> Text.convert_string(language, "content")

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          # |> TextParser.put_non_nil(:credits, parse_credits(result["actors"], "actor"))
          # |> TextParser.put_non_nil(:credits, parse_credits(result["directors"], "director"))
          # |> TextParser.put_non_nil(:credits, parse_credits(result["presenters"], "presenter"))
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
      ~r/^Kausi (?<season_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^(?<episode_num>\d+)\/(?<of_episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^(osa|jakso) (?<episode_num>\d+)\/(?<of_episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^(osa|jakso) (?<episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Kausi (?<season_num>\d+), (?<episode_num>\d+)\/(?<of_episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Kausi (?<season_num>\d+), (osa|jakso) (?<episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Kausi (?<season_num>\d+), (osa|jakso) (?<episode_num>\d+)\/(?<of_episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/HD\.$/,
      %{"qualifiers" => ["HD"]}
    )
    |> StringMatcher.add_regexp(
      ~r/^\(U\)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^O: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^R: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Ohjaus: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Pääosissa: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^S: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.match_captures(string)
  end

  # Venetsia provides the wrong timezone
  defp parse_datetime(datetime) do
    datetime
    |> Okay.trim()
    |> String.replace(~r/\+(\d{2})\:(\d{2})$/, "")
    |> Timex.parse!("%FT%H:%M:%S", :strftime)
    |> Timex.to_datetime("Europe/Helsinki")
    |> Timex.Timezone.convert("UTC")
  end

  def clean_title(string) do
    string
    |> Okay.replace(~r/\(\d+\)$/, "")
    |> Okay.trim()
    |> Okay.replace(~r/(Elokuva|Elokuvat|Kino|Toimintakomedia|Tosiputki|Kyttäputki)\:/i, "")
    |> Okay.replace(~r/\((S|T)\)$/i, "")
    |> Okay.trim()
  end

  defp parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/_(?<year>[0-9]{4}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)/i,
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
