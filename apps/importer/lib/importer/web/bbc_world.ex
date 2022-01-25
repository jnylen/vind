NimbleCSV.define(Importer.Web.BBCWorld.Parser, separator: "\t", escape: "<<<>>")

defmodule Importer.Web.BBCWorld do
  @moduledoc """
  Importer for Anixe Germany
  """

  use Importer.Base.Periodic, type: "daily"

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Web.BBCWorld.Parser

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
      |> NewBatch.set_timezone("Europe/Berlin")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process(body, tuple) do
    body
    |> Parser.parse_string()
    |> Okay.reject(fn airing ->
      is_blank?(Enum.at(airing, 0)) || is_blank?(Enum.at(airing, 1)) ||
        is_blank?(Enum.at(airing, 2))
    end)
    |> Okay.map(fn airing ->
      # [date, time, content_title, content_subtitle, description, _]
      %{
        start_time: parse_datetime(Enum.at(airing, 0), Enum.at(airing, 1)),
        titles: Text.convert_string(Enum.at(airing, 2) |> Text.norm(), "en", "content"),
        subtitles: Text.convert_string(Enum.at(airing, 3) |> Text.norm(), "en", "content"),
        descriptions: Text.convert_string(Enum.at(airing, 4) |> Text.norm(), "en", "content")
      }
    end)
    |> process_items(tuple)
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items([], tuple), do: tuple

  defp process_items([item | items], tuple) do
    process_items(
      items,
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%0d/%0m/%Y %H:%M", :strftime)
  end

  defp is_blank?(nil), do: true
  defp is_blank?(""), do: true
  defp is_blank?(_), do: false

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, _channel) do
    import ExPrintf

    [year, month, day] = date |> String.split("-")

    new_date = "#{day}/#{month}/#{year}"

    sprintf(
      "%s?TimeZone=395&Format=Text&StartDate=%s&EndDate=%s",
      [
        config.url_root,
        new_date,
        new_date
      ]
    )
  end
end
