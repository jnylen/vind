defmodule Importer.File.PlanetTV do
  @moduledoc """
  Importer for Planet TV
  """

  use Importer.Base.File

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.Struppi, as: Parser

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    if Regex.match?(~r/\.xml$/i, file_name) do
      process(file, channel)
    else
      {:error, "not a correct format of file"}
    end
    |> start_batch(channel, file_name)
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, file_name) do
    parsed_file_name = parse_filename(file_name, channel)

    case parsed_file_name do
      {:error, "unable to parse batch_name from file_name"} ->
        NewBatch.dummy_batch()
        |> process_items_new_batch(items, channel)

      val ->
        NewBatch.start_batch(val, channel, "UTC")
        |> process_items(items, channel)
    end
  end

  defp process_items_new_batch(tuple, [], _), do: tuple

  defp process_items_new_batch(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  # Have to due to VG Media License
  defp process(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> stream_file!()
      |> Parser.parse(channel)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(~r/PW(?<week>[0-9]+?)_(?<year>[0-9]{4}?)/i, Path.basename(filename)) do
      %{"week" => week, "year" => year} ->
        "#{year}-#{week}"

        sprintf("%s_%04d-%02d", [
          channel.xmltv_id,
          String.to_integer(year),
          String.to_integer(week)
        ])

      _ ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end
end
