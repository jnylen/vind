defmodule Importer.File.MediasetIT do
  @moduledoc """
  Importer for Mediaset Italy
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser
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
    process(file, channel)
    |> start_batch(channel, file_name)
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, file_name) do
    NewBatch.start_batch(parse_filename(channel, file_name), channel, "Europe/Rome")
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
        ~x"//Record"l,
        date: ~x"./Data/text()"S,
        time: ~x"./Ora/text()"S,
        full_title: ~x"./Titolo/text()"S |> transform_by(&Text.norm/1),
        content_title: ~x"./TitoloProd/text()"S |> transform_by(&Text.norm/1),
        content_subtitle: ~x"./TitoloElem/text()"So |> transform_by(&Text.norm/1),
        content_description: ~x"./Note/text()"So |> transform_by(&Text.norm/1),
        type: ~x"./Tipo/text()"So |> transform_by(&Text.norm/1),
        genre: ~x"./Genere/text()"So |> transform_by(&Text.norm/1),
        production_year: ~x"./Anno/text()"Io
      )
      |> Okay.map(&process_item(&1, channel))
      |> Okay.flatten()
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  # Process a program
  defp process_item(program, _channel) do
    %{
      start_time: parse_datetime(program.date, program.time),
      titles:
        Text.convert_string(
          (program.content_title || program.full_title) |> Text.norm(),
          "it",
          "content"
        )
    }
    |> append_categories(
      Translation.translate_category(
        "MediasetIT_type",
        program.type
      )
    )
    |> append_categories(
      Translation.translate_category(
        "MediasetIT_genre",
        program.genre
      )
    )
    |> parse_description(program.content_description)

    # |> Enum.to_list()
  end

  def parse_description(airing, desc) do
    results =
      split_text(desc)
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
      |> Text.convert_string("it", "content")

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:episode, Text.to_integer(result["episode_num"]))
          |> TextParser.put_non_nil(:season, Text.to_integer(result["season_num"]))
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

  # Description regex parsing
  defp description_regex(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/^S(?<season_num>\d+) Ep(?<episode_num>\d+) (?<subtitle>.*)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^S(?<season_num>\d+) Ep(?<episode_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.match_captures(string)
  end

  defp parse_datetime(date, time) do
    parsed_time = Regex.named_captures(~r/^(?<hour>[0-9]+?):(?<mins>[0-9]+?)$/i, time)

    {:ok, date} = Timex.parse(date, "{0D}-{0M}-{YYYY}")

    date
    |> Timex.set(
      hour: String.to_integer(parsed_time["hour"]),
      minute: String.to_integer(parsed_time["mins"])
    )
  end

  defp split_text(nil), do: []

  defp split_text(text) do
    text
    |> String.replace(" - ", ";;")
    |> TextParser.split_text()
  end

  defp parse_filename(channel, filename) do
    import ExPrintf

    case Regex.named_captures(
           ~r/_(?<year>[0-9]{4}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)_/i,
           Path.basename(filename)
         ) do
      %{"year" => year, "month" => month, "day" => day} ->
        # "#{year}-#{month}-#{day}"
        sprintf("%s_%s", [
          channel.xmltv_id,
          Timex.format!(
            {String.to_integer(year), String.to_integer(month), String.to_integer(day)},
            "%Y-%U",
            :strftime
          )
        ])

      _ ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end
end
