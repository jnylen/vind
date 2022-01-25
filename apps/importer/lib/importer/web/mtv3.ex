defmodule Importer.Web.MTV3 do
  @moduledoc """
  Importer for MTV3
  """

  use Importer.Base.Periodic, type: "one"

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.CMore, as: Parser

  alias Importer.Helpers.Okay
  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body}) do
    body
    |> process(channel)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("UTC"),
      channel
    )
  end

  defp process_items({:ok, []}, tuple, _), do: tuple

  defp process_items({:ok, [item | items]}, tuple, channel) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> parse_airing()
      ),
      channel
    )
  end

  def process(body, channel) do
    body
    |> :zlib.gunzip()
    |> Parser.parse(channel)
    |> Okay.filter(fn i ->
      Map.get(i, :titles, []) != [] && Map.get(i, :start_time, nil) != nil
    end)
    |> OK.wrap()
  end

  def parse_airing(airing) do
    airing
    |> Map.delete(:cmore_type)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, _channel) do
    config.url_root
  end
end
