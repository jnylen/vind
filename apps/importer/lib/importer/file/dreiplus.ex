defmodule Importer.File.Dreiplus do
  @moduledoc """
    Importer for 3+, 4+, 5+, 6+
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
    require Logger

    process(file, channel)
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
      |> NewBatch.start_new_batch?(item, channel, "00:00", "Europe/Berlin")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x"//sendeTag"l,
      date: ~x"./@datum"S,
      programs: [
        ~x".//programmElement"l,
        content_title: ~x"./header/stitel/text()"S |> transform_by(&Text.norm/1),
        original_title: ~x"./header/otitel/text()"So |> transform_by(&Text.norm/1),
        date: ~x"./header/kdatum/text()"S,
        time: ~x"./header/szeit/text()"S,
        episode_no: ~x"./header/folgennummer/text()"Io,
        content_description: ~x"./langInhalt/text()"So |> transform_by(&Text.norm/1),
        content_subtitle: ~x"./header/epistitel/text()"So |> transform_by(&Text.norm/1),
        original_subtitle: ~x"./header/oepistitel/text()"So |> transform_by(&Text.norm/1),
        production_year: ~x"./header/produktionsjahr/text()"Io,
        genre: ~x"./header/genre/text()"So |> transform_by(&Text.norm/1),
        production_countries: ~x"./header/produktionsland/text()"So |> transform_by(&Text.norm/1),
        directors: ~x"./stab[@funktion='Regie']/pname/text()"So |> transform_by(&Text.norm/1),
        writers: ~x"./stab[@funktion='Drehbuch']/pname/text()"So |> transform_by(&Text.norm/1),
        producers: ~x"./stab[@funktion='Produzent']/pname/text()"So |> transform_by(&Text.norm/1),
        cast: [
          ~x".//darsteller"lo,
          person: ~x".//pname/text()"S |> transform_by(&Text.norm/1),
          role: ~x".//rname/text()"S |> transform_by(&Text.norm/1)
        ]
      ]
    )
    |> Okay.map(&process_day(&1, channel))
    |> Okay.flatten()
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_day(day, channel) do
    day.programs
    |> Okay.map(&process_item(&1, channel, day.date))
  end

  defp process_item(program, channel, date) do
    %{
      start_time: parse_datetime(date, program.time),
      titles:
        Text.convert_string(
          program.content_title,
          List.first(channel.schedule_languages),
          "content"
        ) ++
          Text.convert_string(
            program.original_title,
            Text.detect_language(program.original_title),
            "original"
          ),
      subtitles:
        Text.convert_string(
          program.content_subtitle,
          List.first(channel.schedule_languages),
          "content"
        ) ++
          Text.convert_string(
            program.original_subtitle,
            Text.detect_language(program.original_subtitle),
            "original"
          ),
      descriptions:
        Text.convert_string(
          program.content_description,
          List.first(channel.schedule_languages),
          "content"
        ),
      episode: program.episode_no
    }
    |> append_categories(Translation.translate_category("Dreiplus", program[:genre]))
  end

  defp parse_datetime(date, time) do
    require Timex

    parsed_time = Regex.named_captures(~r/^(?<hour>[0-9]+?):(?<mins>[0-9]+?)/i, time)

    # Disney does a weird one where hour can be above 24h.
    # Which means it's in the day after.
    # So do if hour > 24 then hour-24 and do + 1 day
    case Timex.parse(date, "{YYYY}-{0M}-{0D}") do
      {:ok, parsed_date} ->
        parsed_date
        |> Timex.set(
          hour: String.to_integer(parsed_time["hour"]),
          minute: String.to_integer(parsed_time["mins"])
        )

      error ->
        error
    end
  end
end
