defmodule Importer.File.NauticalChannel do
  @moduledoc """
  Importer for Nautical Channel
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser

  require OK

  @fields [
    # Both Date and Time
    %{regex: ~r/^Time/i, type: :start_date},
    %{regex: ~r/^Genre/i, type: :genre},
    %{regex: ~r/^English Title/i, type: :content_title},
    %{regex: ~r/^English Description/i, type: :content_description},
    %{regex: ~r/^French Description/i, type: :french_description},
    %{regex: ~r/^Season/i, type: :season_no}
  ]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    if Regex.match?(~r/\.(xlsx|xls)$/i, file_name) do
      # Excel
      import_excel(channel, file)
    else
      {:error, "not a xls/xlsx file"}
    end
    |> start_batch(channel)
  end

  defp start_batch({:error, reason}, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel) do
    NewBatch.dummy_batch()
    |> batch_process_items(items, channel)
  end

  defp batch_process_items(tuple, [], _), do: tuple

  defp batch_process_items(tuple, [item | items], channel) do
    batch_process_items(
      tuple
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp import_excel(_channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    # Parse excel
    {:ok, programs} = Excel.parse(file_name, "csv")
    {:ok, fields} = Excel.field_names(programs, @fields)

    programs
    |> process_items(fields, nil)
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_items([], _, _), do: []

  defp process_items([program | programs], fields, date) do
    start_date = Text.fetch_map_key(program, fields, :start_date)

    cond do
      Regex.match?(~r/(\d+)\/(\d+)\/(\d+)/, start_date) ->
        process_items(programs, fields, start_date |> parse_date())

      Regex.match?(~r/^(\d+)/, start_date) ->
        process_item(start_date, program, fields, date)
        |> Okay.concat(process_items(programs, fields, date))

      true ->
        process_items(programs, fields, date)
    end
  end

  defp process_item(_, _, _, nil), do: []

  defp process_item(time, program, fields, date) do
    {:ok, datetime} = parse_datetime(date, time)

    [
      %{
        start_time: datetime,
        titles:
          Text.convert_string(
            program
            |> Text.fetch_map_key(fields, :content_title)
            |> Text.norm(),
            "en",
            "content"
          ),
        descriptions:
          Text.convert_string(
            program
            |> Text.fetch_map_key(fields, :content_description)
            |> Text.norm(),
            "en",
            "content"
          ) ++
            Text.convert_string(
              program
              |> Text.fetch_map_key(fields, :french_description)
              |> Text.norm(),
              "fr",
              "content"
            )
      }
      |> add_episode(program |> Text.fetch_map_key(fields, :season_no))
    ]
  end

  defp add_episode(airing, nil), do: airing

  defp add_episode(airing, text) do
    results =
      text
      |> TextParser.split_text()
      |> Okay.map(fn string ->
        case parse_subtitle(string) do
          {:error, _} -> {string, %{}}
          {:ok, result} -> {nil, result}
        end
      end)

    spare_text =
      results
      |> Okay.map(fn {string, _} ->
        string |> Text.norm()
      end)
      |> TextParser.join_text()
      |> Text.convert_string("en", "content")

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:episode, Text.to_integer(result["episode_num"]))
          |> TextParser.put_non_nil(:season, Text.to_integer(result["season_num"]))
          |> TextParser.put_non_nil(
            :subtitles,
            Text.convert_string(
              result["subtitle"] |> Text.norm(),
              "en",
              "content"
            )
          )

        {result, TextParser.merge_with_lists(acc, new_result)}
      end)

    airing
    |> Map.put(:subtitles, spare_text)
    |> TextParser.merge_with_lists(result)
  end

  defp parse_subtitle(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/^Season (?<season_num>\d+) Ep (?<episode_num>\d+) - (?<subtitle>\d+)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Season (?<season_num>\d+) Ep (?<episode_num>\d+)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Ep (?<episode_num>\d+) - (?<subtitle>\d+)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Ep (?<episode_num>\d+)/i,
      %{}
    )
    |> StringMatcher.match_captures(string |> Text.norm())
  end

  defp parse_date(string) do
    DateTimeParser.parse_date!(string)
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}

  defp parse_datetime(date, start_time, timezone \\ "Europe/Stockholm") do
    if start_time |> can_parse_date?() do
      {:ok, time} = DateTimeParser.parse_time(start_time |> String.replace(".", ":"))

      {:ok, actual_dt} = NaiveDateTime.new(date, time)

      actual_dt
      |> Timex.to_datetime(timezone)
      |> Timex.Timezone.convert("UTC")
      |> OK.wrap()
    else
      {:error, "couldnt parse date"}
    end
  end
end
