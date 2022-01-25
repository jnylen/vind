defmodule Importer.Web.ERR do
  @moduledoc """
  Temp. ERR importer
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Text

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body} = _data) do
    body
    |> process(
      tuple
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process(body, tuple) do
    body
    |> Jsonrs.decode()
    |> process_items(tuple)
  end

  # TODO: Add qualifiers

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    content_title =
      item["seriesTitle"] |> Text.norm() || item["progTitle"] |> Text.norm() ||
        item["programName"] |> Text.norm()

    # Run new_batch on it
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(%{
        start_time: item["startTime"] |> Timex.from_unix(),
        end_time: item["endTime"] |> Timex.from_unix(),
        titles:
          Text.convert_string(content_title, "et", "content") ++
            Text.convert_string(item["seriesOriginalTitle"] |> Text.norm(), nil, "original"),
        descriptions: Text.convert_string(item["synopsis"] |> Text.norm(), "et", "content"),
        season: item["season"] |> to_correct_no(),
        episode: item["xEpisodeNr"] |> to_correct_no()
      })
    )
  end

  defp to_correct_no(nil), do: nil

  defp to_correct_no(str) when is_binary(str),
    do: String.split(",") |> List.first() |> Text.to_integer() |> to_correct_no

  defp to_correct_no(int) when is_integer(int) do
    if int === 0 do
      nil
    else
      int
    end
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    [year, month, day] = date |> String.split("-")

    sprintf(
      "%s?day=%s&month=%s&year=%s&channel=%s",
      [
        config.url_root,
        day |> String.to_integer() |> to_string(),
        month |> String.to_integer() |> to_string(),
        year |> String.to_integer() |> to_string(),
        channel.grabber_info
      ]
    )
  end
end
