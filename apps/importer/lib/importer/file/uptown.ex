defmodule Importer.File.Uptown do
  @moduledoc """
  Importer for Uptown Classic
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
    %{regex: ~r/^(Dato|Datum)/i, type: :start_date},
    %{regex: ~r/^Start tid/i, type: :start_time},
    %{regex: ~r/^Program/i, type: :content_title}
    # %{regex: ~r/^(Episodetittel|Episod titel)/i, type: :content_subtitle},
    # %{regex: ~r/^(Oppsummering|Sammanfattning)/i, type: :content_description},
    # %{regex: ~r/^(Sesongnummer|S.song)/i, type: :season_no},
    # %{regex: ~r/^(Episodenummer|Episod nummer)/i, type: :episode_no},
    # %{regex: ~r/^Regiss/i, type: :directors},
    # %{regex: ~r/^Skuespillere/i, type: :actors},
    # %{regex: ~r/^Present/i, type: :presenters},
    # %{regex: ~r/^Catch-up/i, type: :has_catchup}
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

  # TODO: Parse more shit?
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
            )
          # descriptions:
          #   Text.convert_string(
          #     program |> Text.fetch_map_key(fields, :content_description) |> Text.norm(),
          #     List.first(channel.schedule_languages),
          #     "content"
          #   ),
          # season: program |> Text.fetch_map_key(fields, :season_no) |> Text.to_integer(),
          # episode: program |> Text.fetch_map_key(fields, :episode_no) |> Text.to_integer()
        }

      # |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :directors), "director"))
      # |> add_credits(parse_credits(Text.fetch_map_key(program, fields, :actors), "actor"))
      # |> add_credits(
      #   parse_credits(Text.fetch_map_key(program, fields, :presenters), "presenter")
      # )
      # |> add_qualifier(
      #   :catchup,
      #   Text.fetch_map_key(program, fields, :has_catchup) |> Text.to_boolean()
      # )

      {:error, _} ->
        nil
    end
  end

  # Parse qualifier
  defp add_qualifier(airing, :catchup, true) do
    airing
    |> Map.put(:qualifiers, Enum.concat(Map.get(airing, :qualifiers, []), ["catchup"]))
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

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}

  # defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(date, start_time, timezone \\ "Europe/Stockholm") do
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
