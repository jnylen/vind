defmodule Importer.File.TVAnytime do
  @moduledoc """
  Importer for TV Anytime-format
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
    if Regex.match?(~r/\.xml$/i, file_name) do
      # XML
      import_xml(file, channel)
    else
      {:error, "not a zip or xml file"}
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
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  # Import the xml
  defp import_xml(file_name, _channel) do
    read_file!(file_name)
    |> parse()
    ~>> xpath(
      ~x"//ProgramDescription"l,
      information: [
        ~x".//ProgramInformation"l,
        program_id: ~x"./@programId"S,
        genres: ~x".//Genre/Name/text()"Slo,
        titles: [
          ~x".//Title"lo,
          value: ~x"./text()"So |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"So |> transform_by(&convert_language/1),
          type: ~x"./@type"So
        ],
        synopsis: [
          ~x".//Synopsis"lo,
          value: ~x"./text()"So |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"So |> transform_by(&convert_language/1),
          length: ~x"./@length"So
        ],
        series_description: [
          ~x".//SeriesDesc"lo,
          value: ~x"./text()"So |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"So |> transform_by(&convert_language/1),
          length: ~x"./@length"So
        ],
        season_num: ~x".//SeasonNumber/text()"Io,
        episode_num: ~x".//EpisodeNumber/text()"Io
      ],
      events: [
        ~x".//ScheduleEvent"l,
        program_id: ~x"./Program/@crid"S,
        start_time: ~x"./PublishedStartTime/text()"S |> transform_by(&parse_datetime/1),
        end_time: ~x"./PublishedEndTime/text()"So |> transform_by(&parse_datetime/1),
        duration: ~x"./PublishedDuration/text()"So,
        is_live: ~x"./Live/@value"So |> Text.transform_to_boolean()
      ]
    )
    |> Okay.flat_map(&process_program(&1[:events], &1[:information]))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_program([], _), do: []

  defp process_program(
         [%{program_id: program_id, start_time: start} | events],
         informations
       ) do
    information = find_information(program_id, informations)

    titles =
      if parse_titles("main", information.titles, "content") != [] do
        parse_titles("main", information.titles, "content")
      else
        parse_titles("", information.titles, "content")
      end

    [
      %{
        start_time: start,
        season: information.season_num,
        episode: information.episode_num,
        titles: titles,
        descriptions:
          parse_descriptions(information.synopsis, "content") ++
            parse_descriptions(information.series_description, "series"),
        subtitles: parse_titles("EpisodeTitle", information.titles, "content")
      }
    ]
    |> Okay.concat(process_program(events, informations))
  end

  defp parse_titles(_, [], _), do: []

  defp parse_titles(type, [%{value: value, type: type, lang: lang} | titles], string_type) do
    Text.convert_string(
      value |> Text.norm(),
      lang,
      string_type
    )
    |> Okay.concat(parse_titles(type, titles, string_type))
  end

  defp parse_titles(_, _, _), do: []

  defp parse_descriptions([], _), do: []

  defp parse_descriptions([%{value: value, lang: lang} | descriptions], string_type) do
    Text.convert_string(
      value |> Text.norm(),
      lang,
      string_type
    )
    |> Okay.concat(parse_descriptions(descriptions, string_type))
  end

  defp parse_descriptions(_, _), do: []

  defp find_information(program_id, informations) do
    informations
    |> Enum.find(fn info -> info.program_id == program_id end)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("{ISO:Extended:Z}")
    |> Timex.Timezone.convert("UTC")
  end

  defp convert_language("EN"), do: "en"
  defp convert_language("SE"), do: "sv"
  defp convert_language(lang), do: lang |> String.downcase()
end
