defmodule Importer.Web.CMore do
  @moduledoc """
  Importer for CMore
  """

  use Importer.Base.Periodic, type: "daily"

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.CMore, as: Parser

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, channel, %{body: body}) do
    body
    |> process(channel)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("UTC")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00"),
      channel
    )
  end

  defp process_items({:ok, []}, tuple, _), do: tuple

  defp process_items({:ok, [item | items]}, tuple, channel) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(
        item
        |> parse_airing()
      ),
      channel
    )
  end

  def process(body, channel) do
    body
    |> Parser.parse(channel)
  end

  def parse_airing(airing) do
    airing
    |> Map.delete(:cmore_type)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    sprintf("%s/xml/%s/%s?channelId=%s", [
      config.url_root,
      date |> to_string(),
      date |> to_string(),
      channel.grabber_info
    ])
  end
end
