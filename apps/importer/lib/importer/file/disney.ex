defmodule Importer.File.Disney do
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
  alias Importer.Helpers.Translation
  alias Shared.Zip

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
      {:error, "not a zip or xls/xlsx file"}
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

  # Parse an excel file. This is the actual importer of the files.
  defp import_excel(channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

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
    |> Text.fetch_map_key(fields, :date)
    |> parse_datetime(Text.fetch_map_key(program, fields, :start_time))
    |> case do
      {:ok, datetime} ->
        %{
          start_time: datetime,
          titles:
            Text.convert_string(
              Text.fetch_map_key(program, fields, :content_title),
              List.first(channel.schedule_languages),
              "content"
            ) ++
              Text.convert_string(
                Text.fetch_map_key(program, fields, :original_title),
                "en",
                "original"
              ),
          descriptions:
            Text.convert_string(
              Text.fetch_map_key(program, fields, :content_description),
              List.first(channel.schedule_languages),
              "content"
            ) ++
              Text.convert_string(
                Text.fetch_map_key(program, fields, :original_description),
                "en",
                "content"
              ),
          season: Text.to_integer(Text.fetch_map_key(program, fields, :season)),
          episode: Text.to_integer(Text.fetch_map_key(program, fields, :episode))
        }
        |> append_categories(
          Translation.translate_category("Disney", Text.fetch_map_key(program, fields, :category))
        )
        |> add_qualifier("language", Text.fetch_map_key(program, fields, :language))

      {:error, _} ->
        nil
    end
  end

  defp parse_datetime(date, time) do
    require Timex

    # Disney does a weird one where hour can be above 24h.
    # Which means it's in the day after.
    # So do if hour > 24 then hour-24 and do + 1 day
    case Timex.parse(date, "{0D}/{0M}/{YYYY}") do
      {:ok, parsed_date} ->
        add_correct_time(parsed_date, time)
        |> Timex.to_datetime("Europe/Stockholm")
        |> Timex.Timezone.convert("UTC")
        |> OK.wrap()

      error ->
        error
    end
  end

  defp add_correct_time(date, time) do
    # import Timex

    parsed_time = parse_time(time)

    if String.to_integer(parsed_time["hour"]) >= 24 do
      # Add one day
      # Shift with the additional hours
      date
      |> Timex.shift(days: 1)
      |> Timex.set(
        hour: String.to_integer(parsed_time["hour"]) - 24,
        minute: String.to_integer(parsed_time["mins"])
      )
    else
      date
      |> Timex.set(
        hour: String.to_integer(parsed_time["hour"]),
        minute: String.to_integer(parsed_time["mins"])
      )
    end
  end

  defp parse_time(time) do
    Regex.named_captures(~r/^(?<hour>[0-9]+?):(?<mins>[0-9]+?):/i, time)
  end

  # Does a check if the file is a excel file
  # and also check so the file matches towards regex.
  defp file_is_excel?(file_name, regex) do
    case Regex.match?(~r/\.(xlsx|xls)$/i, file_name) do
      true -> Regex.match?(regex, file_name)
      false -> false
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

          Regex.match?(~r/^date/i, text) ->
            [date: index]

          Regex.match?(~r/^title/i, text) &&
              Regex.match?(
                Regex.compile!(translated_title(List.first(channel.schedule_languages)), [
                  :caseless
                ]),
                text
              ) ->
            [content_title: index]

          Regex.match?(~r/^title/i, text) && Regex.match?(~r/eng/i, text) ->
            [original_title: index]

          Regex.match?(~r/^synopsis/i, text) &&
              Regex.match?(
                Regex.compile!(translated_title(List.first(channel.schedule_languages)), [
                  :caseless
                ]),
                text
              ) ->
            [content_description: index]

          Regex.match?(~r/^synopsis/i, text) && Regex.match?(~r/eng/i, text) ->
            [original_description: index]

          Regex.match?(~r/^genre/i, text) ->
            [category: index]

          Regex.match?(~r/^season number/i, text) ->
            [season: index]

          Regex.match?(~r/^episode number/i, text) ->
            [episode: index]

          Regex.match?(~r/^language/i, text) ->
            [language: index]

          Regex.match?(~r/^time/i, text) ->
            [start_time: index]

          true ->
            []
        end
      end
      |> Okay.flatten()

    case fields do
      [] ->
        field_names(channel, list)

      matched ->
        if Keyword.has_key?(matched, :date) && Keyword.has_key?(matched, :episode) do
          {:ok, matched}
        else
          field_names(channel, list)
        end
    end
  end

  defp translated_title(lang) do
    case lang do
      "sv" -> "swedish"
      "fi" -> "finnish"
      "nb" -> "norwegian"
      "no" -> "norwegian"
      "da" -> "danish"
      _ -> ""
    end
  end

  # Add qualifiers fromitem to airing
  defp add_qualifier(airing, "language", data) do
    case data do
      "Subbed" ->
        airing
        |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["CC"]))

      "Dubbed" ->
        airing
        |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["dubbed"]))

      _ ->
        airing
    end
  end
end
