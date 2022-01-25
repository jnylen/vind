defmodule Importer.File.Amb do
  use Importer.Base.File

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.Viasat, as: Parser

  require OK
  use OK.Pipe

  @moduledoc """
    Importer for channels aired by All Media Baltics.

    Mostly Estonia.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    file
    |> process(channel)
    |> start_batch(parse_filename(file_name, channel), channel)
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}
  defp start_batch(_, {:error, reason}, _), do: {:error, reason}

  defp start_batch({:ok, items}, batch_name, channel) do
    NewBatch.start_batch(batch_name, channel)
    |> process_items(items)
  end

  defp process_items(tuple, []), do: tuple

  defp process_items(tuple, [item | items]) do
    process_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items
    )
  end

  defp process(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> stream_file!()
      |> Parser.parse(channel)
    else
      {:error, "file does not exist"}
    end
  end

  defp parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(~r/W(?<week>[0-9]+?)-(?<year>[0-9]{4}?)/i, Path.basename(filename)) do
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
