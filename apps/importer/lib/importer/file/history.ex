defmodule Importer.File.History do
  use Importer.Base.File

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.GlobalListings.XML, as: XMLParser
  alias Importer.Parser.GlobalListings.Word, as: DOCParser

  require OK
  use OK.Pipe

  @moduledoc """
  Importer for channels aired by History.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    Path.extname(file_name)
    |> String.downcase()
    |> process(file, channel)
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
      |> NewBatch.start_new_batch?(item, channel, "00:00", "Europe/Stockholm")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process(".doc", file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> DOCParser.parse(channel)
      |> parse_doc_airings()
      |> Enum.reject(fn map -> Map.get(map, :start_time) |> is_nil() end)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp parse_doc_airings({:ok, airings}), do: parse_doc_airing(nil, airings)

  defp parse_doc_airing(_date, [{"date", val} | airings]), do: parse_doc_airing(val, airings)

  defp parse_doc_airing(date, [{"airing", map} | airings]) do
    [
      map |> Map.put(:start_time, "#{date} #{Map.get(map, :start_time)}" |> parse_datetime())
      | parse_doc_airing(date, airings)
    ]
  end

  defp parse_doc_airing(nil, [_ | airings]), do: parse_doc_airing(nil, airings)

  defp parse_doc_airing(_date, []), do: []

  defp process(".xml", file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> stream_file!()
      |> XMLParser.parse(channel)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string, to_utc: true) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end
end
