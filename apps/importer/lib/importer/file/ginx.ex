defmodule Importer.File.Ginx do
  @moduledoc """
  Importer for Ginx
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Text

  require OK

  @fields [
    %{regex: ~r/^Date/i, type: :start_date},
    %{regex: ~r/^Start time/i, type: :start_time},
    %{regex: ~r/^Program Title$/i, type: :content_title},
    %{regex: ~r/^Comment$/i, type: :content_description},
    %{regex: ~r/^Series$/i, type: :season_no},
    %{regex: ~r/^Episode$/i, type: :episode_no}
  ]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    import_excel(channel, file)
  end

  defp import_excel(channel, file_name) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    # Parse excel
    {:ok, programs} = Excel.parse(file_name, "csv")
    {:ok, fields} = Excel.field_names(programs, @fields)

    NewBatch.dummy_batch()
    |> process_items(programs, fields, channel)
  end

  defp process_items(tuples, [], _, _), do: tuples

  defp process_items(
         {:ok, _, date_map, _} = tuples,
         [program | programs],
         fields,
         channel
       ) do
    date =
      program
      |> Text.fetch_map_key(fields, :start_date)
      |> parse_date()

    # nil?
    if is_nil(date) do
      process_items(tuples, programs, fields, channel)
    else
      time =
        program
        |> Text.fetch_map_key(fields, :start_time)
        |> parse_time()
        |> to_string()

      # nil?
      if is_nil(time) do
        # Add date?
        process_items(tuples, programs, fields, channel)
      else
        case Map.get(date_map, :current_date, "x") do
          "x" ->
            batch_name(channel, date)
            |> NewBatch.start_batch(channel)
            |> NewBatch.start_date(date, "00:00")

          current_date ->
            if NewBatch.same_date?(current_date, date) do
              tuples
            else
              tuples
              |> NewBatch.end_batch()

              batch_name(channel, date)
              |> NewBatch.start_batch(channel)
              |> NewBatch.start_date(date, "00:00")
            end
        end
        |> NewBatch.add_airing(%{
          start_time: time,
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
        })
        |> process_items(programs, fields, channel)
      end
    end
  end

  defp batch_name(channel, date) do
    "#{channel.xmltv_id}_#{Timex.to_date(date)}"
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_date(date) do
    if can_parse_date?(date) do
      DateTimeParser.parse_date!(date)
    end
  end

  defp parse_time(time) do
    DateTimeParser.parse_time!(time)
  end
end
