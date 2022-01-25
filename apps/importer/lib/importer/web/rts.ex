defmodule Importer.Web.RTS do
  @moduledoc """
  Importer for RTS
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body}) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  defp process(body) do
    body
    |> Jsonrs.decode()
    |> Okay.get("schedules")
    |> Okay.first()
    |> Okay.get("broadcasts")
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add qualifiers etc
  defp process_item(item) do
    %{
      start_time: item["plannedBroadcastingEndTime"] |> parse_datetime(),
      end_time: item["plannedBroadcastingStartTime"] |> parse_datetime(),
      titles:
        Text.convert_string(
          Enum.at(item["titles"], 0),
          "fr",
          "content"
        ),
      subtitles:
        Text.convert_string(
          Enum.at(item["titles"], 1),
          "fr",
          "content"
        ),
      descriptions:
        Text.convert_string(
          item["description"],
          "fr",
          "content"
        )
    }
  end

  defp parse_datetime(start_time) do
    {:ok, datetime} = DateTime.from_unix(start_time, :millisecond)

    datetime
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    sprintf("%s/%s?channel=%s", [
      config.url_root,
      date,
      channel.grabber_info
    ])
  end
end
