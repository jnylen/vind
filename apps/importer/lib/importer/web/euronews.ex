defmodule Importer.Web.Euronews do
  @moduledoc """
    Importer for Euronews
  """

  use Importer.Base.Periodic, type: "monthly"
  use Importer.Helpers.Translation

  alias Importer.Parser.Excel
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation

  require OK

  @fields [
    %{regex: ~r/^date/i, type: :start_date},
    %{regex: ~r/^programme title/i, type: :content_title},
    %{regex: ~r/^epg synopsis/i, type: :content_description},
    %{regex: ~r/^theme/i, type: :genre},
    %{regex: ~r/^start time/i, type: :start_time}
  ]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    {:ok, path} = Briefly.create(extname: ".xlsx")
    File.write!(path, body)

    import_excel(channel, path)
    |> process_items(tuple)
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item)
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

  # TODO: Add genre
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
        |> append_categories(
          Translation.translate_category("Euronews", Text.fetch_map_key(program, fields, :genre))
        )

      {:error, _} ->
        nil
    end
  end

  defp can_parse_date?(date), do: Regex.match?(~r/^(\d+)/, date)

  defp parse_datetime(_, nil, _), do: {:error, "no time supplied"}
  defp parse_datetime(nil, _, _), do: {:error, "no date supplied"}

  # defp parse_datetime(_, _, nil), do: {:error, "no timezone supplied"}

  defp parse_datetime(date, start_time, timezone \\ "CET") do
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

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, _channel) do
    import ExPrintf

    [year, month] = date |> String.split("-")

    sprintf("%s/EN/%s/%s/enws_cetcest.xlsx", [
      config.url_root,
      year,
      month
    ])
  end
end
