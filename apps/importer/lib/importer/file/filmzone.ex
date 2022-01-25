defmodule Importer.File.Filmzone do
  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation

  require OK

  @moduledoc """
    Importer for BBC Channels
    Sent by EBS
  """

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
    |> process(channel)
  end

  defp process({:error, reason}, _), do: {:error, reason}

  defp process({:ok, items}, channel) do
    NewBatch.dummy_batch()
    |> process_airings(items, channel)
  end

  defp process_airings(tuple, [], _), do: tuple

  defp process_airings(tuple, [item | items], channel) do
    process_airings(
      tuple
      |> NewBatch.start_new_batch?(item, channel, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  # Import excel
  defp import_excel(channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    {:ok, programs} = Excel.parse(file_name, "csv", channel, channel.grabber_info)
    {:ok, fields} = field_names(channel, programs)

    programs
    |> Enum.map(&process_item(&1, fields, channel))
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_item(program, fields, channel) do
    parse_datetime(
      Text.fetch_map_key(program, fields, :date),
      Text.fetch_map_key(program, fields, :start_time),
      worksheet_to_tz(channel.grabber_info)
    )
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
        |> append_countries(
          Translation.translate_country("BBC", Text.fetch_map_key(program, fields, :country))
        )
        |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :directors), "director"))
        |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :cast), "actor"))
        |> add_credits(
          parse_credits(Text.fetch_map_key(program, fields, :presenters), "presenter")
        )
        |> add_production_year(
          Text.to_integer(Text.fetch_map_key(program, fields, :production_year))
        )

      {:error, _} ->
        nil
    end
  end

  defp add_production_year(airing, nil), do: airing

  defp add_production_year(airing, production_year) do
    airing
    |> Map.put(:production_date, Text.year_to_date(production_year))
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}

  # defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(date, start_time, timezone \\ "EET") do
    if date |> can_parse_date?() do
      date = date |> Timex.parse!("{YYYY}/{0M}/{0D}") |> NaiveDateTime.to_date()
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

          Regex.match?(~r/title/i, text) && Regex.match?(~r/English/i, text) ->
            [original_title: index]

          # [title: index]

          Regex.match?(~r/title/i, text) &&
              Regex.match?(
                Regex.compile!(translated_title(List.first(channel.schedule_languages)), [
                  :caseless
                ]),
                text
              ) ->
            [content_title: index]

          Regex.match?(~r/synopsis/i, text) &&
              Regex.match?(
                Regex.compile!(translated_title(List.first(channel.schedule_languages)), [
                  :caseless
                ]),
                text
              ) ->
            [content_description: index]

          Regex.match?(~r/synopsis/i, text) &&
              Regex.match?(
                Regex.compile!("English", [
                  :caseless
                ]),
                text
              ) ->
            [original_description: index]

          Regex.match?(~r/^english synopsis/i, text) &&
              Regex.match?(
                Regex.compile!("English", [
                  :caseless
                ]),
                text
              ) ->
            [original_description: index]

          Regex.match?(~r/^series$/i, text) ->
            [season: index]

          Regex.match?(~r/^episode$/i, text) ->
            [episode: index]

          Regex.match?(~r/^time/i, text) ->
            [start_time: index]

          Regex.match?(~r/^country/i, text) ->
            [country: index]

          Regex.match?(~r/^director/i, text) ->
            [directors: index]

          Regex.match?(~r/^cast/i, text) ->
            [cast: index]

          Regex.match?(~r/^genre/i, text) ->
            [genre: index]

          Regex.match?(~r/^type/i, text) ->
            [program_type: index]

          Regex.match?(~r/^year/i, text) ->
            [production_year: index]

          true ->
            []
        end
      end
      |> Okay.flatten()

    case fields do
      [] ->
        field_names(channel, list)

      matched ->
        case Keyword.has_key?(matched, :date) do
          true -> {:ok, matched}
          false -> field_names(channel, list)
        end
    end
  end

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

  # Add credits
  defp add_credits(%{} = airing, list) when is_list(list) do
    airing
    |> Map.put(:credits, (Map.get(airing, :credits) || []) ++ list)
  end

  defp translated_title(lang) do
    case lang do
      "et" -> "estonian"
      "lt" -> "lithuanian"
      "lv" -> "latvian"
      "ru" -> "russian"
      "en" -> "english"
      _ -> ""
    end
  end

  defp worksheet_to_tz(nil), do: "EET"

  defp worksheet_to_tz(worksheet) do
    case worksheet |> String.downcase() do
      _ -> "EET"
    end
  end
end
