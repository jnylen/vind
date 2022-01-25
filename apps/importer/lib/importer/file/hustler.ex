# TODO: FIX, THEY ARE USING SOME WEIRD ASS START_TIME OF DATES
defmodule Importer.File.Hustler do
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
    |> process_items(fields, channel, nil)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_items([program | programs], fields, channel, date) do
    date =
      case parse_datetime(get_key(program, 2)) do
        {:ok, new_date} -> new_date
        {:error, _} -> date
      end

    # Is a program!
    parsed_program =
      if date != nil && program |> get_key(0) |> Text.norm() != nil do
        time =
          program
          |> get_key(0)

        # Create datetime
        {:ok, datetime} = parse_time(date, time)

        %{
          start_time: datetime,
          titles:
            Text.convert_string(
              program
              |> get_key(2)
              |> clean_title(),
              List.first(channel.schedule_languages),
              "content"
            ),
          descriptions:
            Text.convert_string(
              program |> Text.fetch_map_key(fields, :content_description) |> Text.norm(),
              List.first(channel.schedule_languages),
              "content"
            ),
          credits: parse_cast(Text.fetch_map_key(program, fields, :cast))
        }
      end

    [process_items(programs, fields, channel, date) | [parsed_program]]
  end

  defp process_items([], _, _, _), do: []

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

          Regex.match?(~r/^Synopsis$/i, text) ->
            [content_description: index]

          Regex.match?(~r/^Cast$/i, text) ->
            [cast: index]

          Regex.match?(~r/^Year of production$/i, text) ->
            [production_year: index]

          Regex.match?(~r/^Production Studio$/i, text) ->
            [production_studio: index]

          true ->
            []
        end
      end
      |> Okay.flatten()

    case fields do
      [] ->
        field_names(channel, list)

      matched ->
        case Keyword.has_key?(matched, :cast) do
          true -> {:ok, matched}
          false -> field_names(channel, list)
        end
    end
  end

  defp can_parse_date?(date), do: Regex.match?(~r/(\d\d\d\d)/, date)

  defp parse_datetime(date) do
    if date |> can_parse_date?() do
      DateTimeParser.parse_date(date)
    else
      {:error, "cant parse date"}
    end
  end

  defp can_parse?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_time(_, nil, _), do: {:error, "no time supplied"}
  defp parse_time(nil, _, _), do: {:error, "no date supplied"}

  defp parse_time(date, start_time, timezone \\ "CET") do
    if start_time |> can_parse?() do
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

  defp clean_title(title) do
    title
    |> Okay.replace(~r/^PREMIERE/i, "")
    |> Okay.replace(~r/^HUSTLER TV/i, "")
    |> Okay.replace("#", "")
    |> Okay.trim()
    |> Okay.replace(~r/^-/, "")
    |> Okay.trim()
  end

  defp parse_cast(nil), do: []

  defp parse_cast(cast) do
    if Regex.match?(~r/^Various/i, cast) do
      []
    else
      cast
      |> String.split(";")
      |> Okay.map(fn credit ->
        names = String.split(credit, ",")

        %{
          type: "actor",
          person: names |> Enum.reverse() |> Enum.join(" ") |> Text.norm()
        }
      end)
    end
  end

  defp get_key(program, at), do: (Enum.at(program, at) || %{}) |> Map.get(:value)
end
