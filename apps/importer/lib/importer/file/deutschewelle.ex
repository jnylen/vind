defmodule Importer.File.DeutscheWelle do
  @moduledoc """
    Importer for DW Channels
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
    %{regex: ~r/^startdate/i, type: :start_date},
    %{regex: ~r/^date/i, type: :start_date},
    %{regex: ~r/^Horarios locales/i, type: :start_date},
    %{regex: ~r/^programme_title/i, type: :content_title},
    %{regex: ~r/^title$/i, type: :content_title},
    %{regex: ~r/^episode_title/i, type: :content_subtitle},
    %{regex: ~r/^synopsis/i, type: :content_description},
    %{regex: ~r/^genre/i, type: :genre},
    %{regex: ~r/^time/i, type: :start_time},
    %{regex: ~r/^utc$/i, type: :start_time},
    %{regex: ~r/^Todos los horarios/i, type: :start_time}
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

  # TODO: Add genres
  defp process_item(program, fields, channel) do
    program
    |> Text.fetch_map_key(fields, :start_date)
    |> parse_datetime(Text.fetch_map_key(program, fields, :start_time), channel.grabber_info)
    |> case do
      {:ok, datetime} ->
        %{
          start_time: datetime,
          titles:
            Text.convert_string(
              Text.fetch_map_key(program, fields, :content_title),
              List.first(channel.schedule_languages),
              "content"
            ),
          descriptions:
            Text.convert_string(
              Text.fetch_map_key(program, fields, :content_description),
              List.first(channel.schedule_languages),
              "content"
            )
        }

      {:error, _} ->
        nil
    end
  end

  defp parse_datetime(date, start_time, timezone \\ "UTC") do
    cond do
      can_parse?(start_time) && can_parse?(date) ->
        {:ok, date} = DateTimeParser.parse_date(date)
        {:ok, time} = DateTimeParser.parse_time(start_time)

        {:ok, actual_dt} = NaiveDateTime.new(date, time)

        actual_dt
        |> Timex.to_datetime(timezone)
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      can_parse?(date) ->
        {:ok, actual_dt} = DateTimeParser.parse_datetime(date)

        actual_dt
        |> Timex.to_datetime(timezone)
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      true ->
        {:error, "couldnt parse date"}
    end
  end

  defp can_parse?(date), do: Regex.match?(~r/^(\d+)/, date)
end
