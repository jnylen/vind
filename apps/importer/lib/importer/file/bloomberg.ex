defmodule Importer.File.Bloomberg do
  @moduledoc """
  Importer for Bloomberg
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  require OK

  @fields [
    %{regex: ~r/^Schedule date/i, type: :start_date},
    %{regex: ~r/^Schedule start time/i, type: :start_time},
    %{regex: ~r/^Slot Name$/i, type: :content_title},
    %{regex: ~r/^Episode Title$/i, type: :content_subtitle},
    %{regex: ~r/^Synopsis$/i, type: :content_description},
    %{regex: ~r/^HD$/i, type: :is_hd},
    %{regex: ~r/^Widescreen$/i, type: :is_ws},
    %{regex: ~r/^Season Number$/i, type: :season_no},
    %{regex: ~r/^Episode Number$/i, type: :episode_no}
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

  defp import_excel(channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    # Parse excel
    {:ok, programs} = Excel.parse(file_name, "csv")
    {:ok, fields} = Excel.field_names(programs, @fields)

    programs
    |> Enum.map(&process_item(&1, fields, channel))
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_item(program, fields, channel) do
    program
    |> Text.fetch_map_key(fields, :start_date)
    |> parse_datetime(Text.fetch_map_key(program, fields, :start_time))
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
            ),
          season: program |> Text.fetch_map_key(fields, :season_no) |> Text.to_integer(),
          episode: program |> Text.fetch_map_key(fields, :episode_no) |> Text.to_integer()
        }
        |> add_qualifiers(:hd, program, fields)
        |> add_qualifiers(:ws, program, fields)

      {:error, _} ->
        nil
    end
  end

  defp add_qualifiers(airing, :hd, program, fields) do
    if Text.fetch_map_key(program, fields, :is_hd) |> Text.to_boolean() do
      airing
      |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["HD"]))
    else
      airing
    end
  end

  defp add_qualifiers(airing, :ws, program, fields) do
    if Text.fetch_map_key(program, fields, :is_ws) |> Text.to_boolean() do
      airing
      |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["widescreen"]))
    else
      airing
    end
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}

  # defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(date, start_time, timezone \\ "UTC") do
    if date |> can_parse_date?() do
      {:ok, date} = DateTimeParser.parse_date(date)
      {:ok, time} = DateTimeParser.parse_time(start_time)

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
