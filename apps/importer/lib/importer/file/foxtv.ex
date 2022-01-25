defmodule Importer.File.FoxTV do
  @moduledoc """
  Importer for Disney Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper, as: ParserHelper

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @fields [
    %{regex: ~r/^Date/i, type: :start_date},
    %{regex: ~r/^Minsk time/i, type: :start_time},
    %{regex: ~r/^Time$/i, type: :start_time},
    %{regex: ~r/Baltics Time/i, type: :start_time},
    %{regex: ~r/Time Baltics/i, type: :start_time},
    %{regex: ~r/^Start time/i, type: :start_time},
    %{regex: ~r/^Longline/i, type: :genre},
    %{regex: ~r/^Local Title$/i, type: :content_title},
    %{regex: ~r/^Program Title$/i, type: :content_title},
    %{regex: ~r/^Series Name English$/i, type: :original_title},
    %{regex: ~r/^Original Title$/i, type: :original_title},
    %{regex: ~r/^Original Title Series$/i, type: :original_title},
    %{regex: ~r/^Episode Title$/i, type: :content_subtitle},
    %{regex: ~r/^Original Episode Title$/i, type: :original_subtitle},
    %{regex: ~r/^Episode Synopsis$/i, type: :content_description},
    %{regex: ~r/^Synopsis English$/i, type: :content_description},
    %{regex: ~r/^Synopsis$/i, type: :content_description},
    %{regex: ~r/^Season Synopsis$/i, type: :season_description},
    %{regex: ~r/^Actors/i, type: :actors},
    %{regex: ~r/^Directors/i, type: :directors},
    %{regex: ~r/^Season Number/i, type: :season_no},
    %{regex: ~r/^Season$/i, type: :season_no},
    %{regex: ~r/^Episode Number/i, type: :episode_no},
    %{regex: ~r/^Ep No/i, type: :episode_no},
    %{regex: ~r/^High Def/i, type: :is_hd},
    %{regex: ~r/^16\:9/i, type: :is_ws}
  ]

  @fields_est [
    %{regex: ~r/^Episode Title Estonian$/i, type: :content_subtitle},
    %{regex: ~r/^Synopsis Estonian$/i, type: :content_description},
    %{regex: ~r/^Series Name Estonian$/i, type: :content_title}
  ]

  @fields_lit [
    %{regex: ~r/^Episode Name Lithuanian$/i, type: :content_subtitle},
    %{regex: ~r/^Episode Title Lithuanian$/i, type: :content_subtitle},
    %{regex: ~r/^Synopsis Lithuanian$/i, type: :content_description},
    %{regex: ~r/^Series Name Lithuanian$/i, type: :content_title}
  ]

  @fields_lat [
    %{regex: ~r/^Episode Name Latvian$/i, type: :content_subtitle},
    %{regex: ~r/^Episode Title Latvian$/i, type: :content_subtitle},
    %{regex: ~r/^Synopsis Latvian$/i, type: :content_description},
    %{regex: ~r/^Series Name Latvian$/i, type: :content_title}
  ]

  @fields_rus [
    %{regex: ~r/^Episode Title Russian$/i, type: :content_subtitle},
    %{regex: ~r/^Synopsis Russian$/i, type: :content_description},
    %{regex: ~r/^Series Name Russian$/i, type: :content_title}
  ]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    cond do
      Regex.match?(~r/\.(xlsx|xls)$/i, file_name) ->
        # Excel
        import_excel(channel, file)

      Regex.match?(~r/\.xml$/i, file_name) ->
        # XML
        import_xml(file, channel)

      true ->
        {:error, "not a xls/xlsx/xml file"}
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

  defp excel_fields(channel) do
    cond do
      Enum.member?(channel.schedule_languages, "et") ->
        @fields ++ @fields_est

      Enum.member?(channel.schedule_languages, "lt") ->
        @fields ++ @fields_lit

      Enum.member?(channel.schedule_languages, "lv") ->
        @fields ++ @fields_lat

      Enum.member?(channel.schedule_languages, "ru") ->
        @fields ++ @fields_rus

      true ->
        @fields
    end
  end

  defp import_excel(channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    # Parse excel
    actual_fields = excel_fields(channel)
    {:ok, programs} = Excel.parse(file_name, "csv")
    {:ok, fields} = Excel.field_names(programs, actual_fields)

    programs
    |> Enum.map(&process_excel_item(&1, fields, channel))
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_excel_item(program, fields, channel) do
    program
    |> Text.fetch_map_key(fields, :start_date)
    |> parse_datetime(Text.fetch_map_key(program, fields, :start_time), channel.grabber_info)
    |> case do
      {:ok, datetime} ->
        %{
          start_time: datetime,
          titles:
            Text.convert_string(
              program
              |> Text.fetch_map_key(fields, :content_title)
              |> Text.norm(),
              List.first(channel.schedule_languages),
              "content"
            ) ++
              Text.convert_string(
                program
                |> Text.fetch_map_key(fields, :original_title)
                |> Text.norm(),
                "en",
                "original"
              ),
          descriptions:
            Text.convert_string(
              program |> Text.fetch_map_key(fields, :content_description) |> Text.norm(),
              List.first(channel.schedule_languages),
              "content"
            ),
          subtitles:
            Text.convert_string(
              program |> Text.fetch_map_key(fields, :content_subtitle) |> Text.norm(),
              List.first(channel.schedule_languages),
              "content"
            ) ++
              Text.convert_string(
                program |> Text.fetch_map_key(fields, :original_subtitle) |> Text.norm(),
                "en",
                "original"
              ),
          season:
            program
            |> Text.fetch_map_key(fields, :season_no)
            |> ParserHelper.grab_int_from_text()
            |> Text.to_integer(),
          episode:
            program
            |> Text.fetch_map_key(fields, :episode_no)
            |> ParserHelper.grab_int_from_text()
            |> Text.to_integer()
        }
        |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :directors), "director"))
        |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :cast), "actor"))
        |> append_categories(
          Translation.translate_category("FoxTV", Text.fetch_map_key(program, fields, :genre))
        )
        |> add_qualifier(:hd, Text.fetch_map_key(program, fields, :is_hd) |> Text.to_boolean())
        |> add_qualifier(:ws, Text.fetch_map_key(program, fields, :is_ws) |> Text.to_boolean())

      {:error, _} ->
        nil
    end
  end

  defp import_xml(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x".//Event"l,
      start_date: ~x"./Date/text()"S,
      start_time: ~x"./StartTime/text()"S,
      content_title: ~x"./ProgrammeTitle/text()"S,
      original_title: ~x"./OriginalProgramTitle/text()"S,
      original_subtitle: ~x"./OriginalEpisodeTitle/text()"S,
      season_description: ~x"./seasonsynopsis/text()"S,
      episode_description: ~x"./episodesynopsis/text()"S,
      original_season_description: ~x"./originalseasonsynopsis/text()"S,
      original_episode_description: ~x"./originalepisodesynopsis/text()"S,
      season_num: ~x"./SeasonNumber/text()"Io,
      episode_num: ~x"./EpisodeNumber/text()"Io
    )
    |> Okay.map(&process_xml_item(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_xml_item(item, channel) do
    parse_xml_datetime(item[:start_date], item[:start_time], channel.grabber_info)
    |> case do
      {:error, _} = _error ->
        nil

      {:ok, datetime} ->
        %{
          start_time: datetime,
          titles:
            Text.convert_string(
              item[:content_title],
              List.first(channel.schedule_languages),
              "content"
            ),
          descriptions:
            Text.convert_string(
              item[:episode_description],
              List.first(channel.schedule_languages),
              "episode"
            ) ++
              Text.convert_string(
                item[:season_description],
                List.first(channel.schedule_languages),
                "season"
              ),
          season: item[:season_num],
          episode: item[:episode_num]
        }
    end
  end

  # Parse qualifier
  defp add_qualifier(airing, :hd, true) do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["HD"]))
  end

  defp add_qualifier(airing, :ws, true) do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["widescreen"]))
  end

  defp add_qualifier(airing, _, _), do: airing

  # Add credits
  defp add_credits(%{} = airing, list) when is_list(list) do
    airing
    |> Map.put(:credits, (Map.get(airing, :credits) || []) ++ list)
  end

  defp parse_credits(",", _), do: []
  defp parse_credits("", _), do: []
  defp parse_credits(nil, _), do: []

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

  defp parse_xml_datetime(date, time, timezone) do
    "#{date} #{time}"
    |> Timex.parse!("%d/%m/%Y %T", :strftime)
    |> Timex.to_datetime(timezone)
    |> Timex.Timezone.convert("UTC")
    |> OK.wrap()
  end

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}
  defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(date, start_time, timezone) do
    cond do
      Regex.match?(~r/^(\d{1,2})\//, date) ->
        date = date |> Timex.parse!("{0D}/{0M}/{YYYY}") |> NaiveDateTime.to_date()
        time = DateTimeParser.parse_time!(start_time)

        {:ok, actual_dt} = NaiveDateTime.new(date, time)

        actual_dt
        |> Timex.to_datetime(timezone)
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      Regex.match?(~r/^(\d+)/, date) ->
        date = DateTimeParser.parse_date!(date)
        time = DateTimeParser.parse_time!(start_time)

        {:ok, actual_dt} = NaiveDateTime.new(date, time)

        actual_dt
        |> Timex.to_datetime(timezone)
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      true ->
        {:error, "couldnt parse date"}
    end
  end
end
