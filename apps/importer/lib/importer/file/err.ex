defmodule Importer.File.ERR do
  use Importer.Base.File
  alias Importer.Helpers.NewBatch
  alias Importer.Parser.ERR, as: Parser
  require OK

  @moduledoc """
  Importer for channels aired by ERR.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    process(file, channel)
    |> start_batch(channel, file_name)
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, file_name) do
    NewBatch.start_batch(parse_filename(file_name, channel), channel, "Europe/Tallinn")
    |> process_items(items, channel)
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

  defp process(file_name, channel) do
    # |> Struppi.process(channel, "{ISO:Extended}", encoding: :latin1)
    file_name
    |> stream_file!()
    |> Parser.parse(channel)
    |> OK.wrap()
  end

  @doc """
  Parse the batch_name from the file_name
  """
  def parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/(?<year>[0-9]{4}?)_Kava(?<week>[0-9]+)/i,
           Path.basename(filename)
         ) do
      %{"week" => week, "year" => year} ->
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
