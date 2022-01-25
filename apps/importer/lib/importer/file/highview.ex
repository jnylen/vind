defmodule Importer.File.Highview do
  @moduledoc """
  Importer for Highview Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

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
      import_xml(channel, file)
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
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  # Import the xml
  defp import_xml(_, file_name) do
    file_name
    |> read_file!()
    |> parse()
    ~>> xpath(
      ~x"//ProgramDescription"l,
      information: [
        ~x".//ProgramInformation"l,
        program_id: ~x"./@programId"S,
        titles: [
          ~x".//Title"l,
          value: ~x"./text()"S |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"S |> transform_by(&convert_language/1),
          type: ~x"./@type"So
        ],
        synopsis: [
          ~x".//Synopsis"l,
          value: ~x"./text()"S |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"S |> transform_by(&convert_language/1),
          length: ~x"./@length"S
        ],
        series_description: [
          ~x".//SeriesDesc"l,
          value: ~x"./text()"S |> transform_by(&Text.norm/1),
          lang: ~x"./@xml:lang"S |> transform_by(&convert_language/1),
          length: ~x"./@length"S
        ],
        season_num: ~x".//SeasonNumber/text()"Io,
        episode_num: ~x".//EpisodeNumber/text()"Io
      ],
      events: [
        ~x".//ScheduleEvent"l,
        program_id: ~x"./Program/@crid"S,
        start_time: ~x"./PublishedStartTime/text()"S |> transform_by(&parse_datetime/1),
        end_time: ~x"./PublishedEndTime/text()"S |> transform_by(&parse_datetime/1)
      ]
    )
    |> Okay.flat_map(&process_program(&1[:events], &1[:information]))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_program([], _), do: []

  # TODO: Add genre
  defp process_program(
         [%{program_id: program_id, start_time: start, end_time: end_time} | events],
         informations
       ) do
    information = find_information(program_id, informations)

    [
      %{
        start_time: start,
        end_time: end_time,
        season: information.season_num,
        episode: information.episode_num,
        titles: parse_titles(information.titles, "content")
      }
    ]
    |> Okay.concat(process_program(events, informations))
  end

  defp parse_titles([], _), do: []

  defp parse_titles([%{value: value, lang: lang} | titles], string_type) do
    Text.convert_string(
      value |> Text.norm(),
      lang,
      string_type
    )
    |> Okay.concat(parse_titles(titles, string_type))
  end

  defp parse_titles(_, _), do: []

  defp find_information(program_id, informations) do
    informations
    |> Enum.find(fn info -> info.program_id == program_id end)
  end

  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("{ISO:Extended:Z}")
    |> Timex.Timezone.convert("UTC")
  end

  defp convert_language(lang), do: lang |> String.downcase()
end
