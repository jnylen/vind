# TODO: Add grids parsing?
defmodule Importer.File.VIMN do
  @moduledoc """
  Importer for VIMN Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Xmltv

  require OK

  @fields [
    %{regex: ~r/^Date/i, type: :start_date},
    %{regex: ~r/^Time/i, type: :start_time},
    %{regex: ~r/^Title/i, type: :content_title},
    %{regex: ~r/^Synopsis/i, type: :content_description},
    %{regex: ~r/^Season /i, type: :season_no},
    %{regex: ~r/^Episode /i, type: :episode_no}
  ]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    cond do
      # Excel
      Regex.match?(~r/\.(xlsx|xls)$/i, file_name) ->
        import_excel(channel, file)

      # XMLTV?
      Regex.match?(~r/\.xml$/i, file_name) ->
        import_xmltv(channel, file)

      true ->
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
          season: program |> Text.fetch_map_key(fields, :season_no) |> Text.to_integer(),
          episode: program |> Text.fetch_map_key(fields, :episode_no) |> Text.to_integer()
        }

      # TODO: Add qualifiers

      {:error, _} ->
        nil
    end
  end

  defp import_xmltv(_, file_name) do
    file_name
    |> read_file!()
    |> Xmltv.process()
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(date, start_time) do
    date =
      if can_parse_date?(date) do
        date |> Timex.parse!("%d/%m/%Y", :strftime)
      end

    if is_nil(date) do
      {:error, nil}
    else
      [hour, min] = start_time |> String.split(":")

      date
      |> Timex.set(
        hour: hour |> String.to_integer(),
        minute: min |> String.to_integer()
      )
      |> Timex.to_datetime("GMT")
      |> Timex.Timezone.convert("UTC")
      |> OK.wrap()
    end
  end
end
