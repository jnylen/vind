defmodule Importer.File.S1CH do
  @moduledoc """
  Importer for S1TV
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
    process(file, channel)
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
end
