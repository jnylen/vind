defmodule Importer.File.BibelTV do
  use Importer.Base.File

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Parser.Xmltv

  require OK
  use OK.Pipe

  @moduledoc """
    Importer for channels aired by BibelTV.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, _file_name, file) do
    file
    |> process()
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

  defp process(file_name) do
    if file_exists?(file_name) do
      file_name
      |> read_file!()
      |> :unicode.characters_to_binary(:latin1)
      |> Okay.replace("\"Windows-1252\"", "\"utf-8\"")
      |> Okay.replace("\"windows-1252\"", "\"utf-8\"")
      |> Xmltv.parse()
      |> Okay.map(fn airing ->
        airing
        |> Map.delete(:descriptions)
      end)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end
end
