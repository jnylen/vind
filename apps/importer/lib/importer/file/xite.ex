defmodule Importer.File.Xite do
  @moduledoc """
  Importer for Xite
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
    content_title: 0,
    content_description: 1,
    start_time: 2
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

    programs
    |> Enum.map(&process_item(&1, @fields, channel))
    |> Enum.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_item(program, fields, channel) do
    program
    |> Text.fetch_map_key(fields, :start_time)
    |> parse_datetime()
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
            )
        }

      # TODO: Add qualifiers

      {:error, _} ->
        nil
    end
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  # defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(start_time, timezone \\ "Europe/Stockholm") do
    if start_time |> can_parse_date?() do
      {:ok, actual_dt} = DateTimeParser.parse_datetime(start_time)

      actual_dt
      |> Timex.to_datetime(timezone)
      |> Timex.Timezone.convert("UTC")
      |> OK.wrap()
    else
      {:error, "couldnt parse date"}
    end
  end
end
