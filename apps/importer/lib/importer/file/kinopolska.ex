defmodule Importer.File.Kinopolska do
  @moduledoc """
  Importer for Disney Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  require OK

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
    {:ok, fields} = field_names(channel, programs)

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
              |> Text.norm()
              |> end_of_transmission(),
              List.first(channel.schedule_languages),
              "content"
            ),
          descriptions:
            Text.convert_string(
              program |> Text.fetch_map_key(fields, :content_description) |> Text.norm(),
              List.first(channel.schedule_languages),
              "content"
            )
        }

      {:error, _} ->
        nil
    end
  end

  # Get field names
  defp field_names(_channel, []), do: {:error, []}

  defp field_names(channel, [item | list]) when is_list(item) do
    item = Enum.map(item, fn i -> Map.get(i, :value) end)

    # does the field names match?
    fields =
      for {text, index} <- Enum.with_index(item) do
        cond do
          is_nil(text) ->
            []

          Regex.match?(~r/^Date$/i, text) ->
            [start_date: index]

          Regex.match?(~r/^Start date/i, text) ->
            [start_date: index]

          Regex.match?(~r/^Data i godzina/i, text) ->
            [start_date: index]

          Regex.match?(~r/^Start time/i, text) ->
            [start_time: index]

          Regex.match?(~r/^End date/i, text) ->
            [end_date: index]

          Regex.match?(~r/^End time/i, text) ->
            [end_time: index]

          Regex.match?(~r/^Title$/i, text) ->
            [content_title: index]

          Regex.match?(~r/^Cykl programu/i, text) ->
            [content_title: index]

          Regex.match?(~r/^Titles$/i, text) ->
            [content_title: index]

          Regex.match?(~r/^Local title/i, text) ->
            [content_title: index]

          Regex.match?(~r/^Synopsis$/i, text) ->
            [content_description: index]

          Regex.match?(~r/^Opis/i, text) ->
            [content_description: index]

          Regex.match?(~r/^Genre$/i, text) ->
            [genre: index]

          Regex.match?(~r/^Director$/i, text) ->
            [director: index]

          Regex.match?(~r/^Casting$/i, text) ->
            [cast: index]

          true ->
            []
        end
      end
      |> Okay.flatten()

    case fields do
      [] ->
        field_names(channel, list)

      matched ->
        case Keyword.has_key?(matched, :start_date) do
          true -> {:ok, matched}
          false -> field_names(channel, list)
        end
    end
  end

  defp parse_datetime(dt, nil) do
    dt
    |> DateTimeParser.parse_datetime(to_utc: true)
  end

  defp parse_datetime(date, time) do
    parsed_time = Regex.named_captures(~r/^(?<hour>[0-9]+?):(?<mins>[0-9]+?)/i, time)

    cond do
      parse_date!(date, "{YYYY}{0M}{0D}") ->
        {:ok, date} = Timex.parse(date, "{YYYY}{0M}{0D}")

        date
        |> Timex.set(
          hour: String.to_integer(parsed_time["hour"]),
          minute: String.to_integer(parsed_time["mins"])
        )
        |> Timex.to_datetime("Europe/Stockholm")
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      parse_date!(date, "{0D}.{0M}.{YYYY}") ->
        {:ok, date} = Timex.parse(date, "{0D}.{0M}.{YYYY}")

        date
        |> Timex.set(
          hour: String.to_integer(parsed_time["hour"]),
          minute: String.to_integer(parsed_time["mins"])
        )
        |> Timex.to_datetime("Europe/Stockholm")
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      true ->
        {:error, "bad format"}
    end
  end

  defp parse_date!(date, format) do
    case Timex.parse(date, format) do
      {:ok, _} ->
        true

      _ ->
        false
    end
  end

  defp end_of_transmission(nil), do: nil

  defp end_of_transmission(text),
    do: text |> String.replace("END OF PROGRAM", "end-of-transmission")
end
