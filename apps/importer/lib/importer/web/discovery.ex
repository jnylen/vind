defmodule Importer.Web.Discovery do
  @moduledoc """
  Importer for EBS-provided Discovery Data.
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.GlobalListings.XML, as: Parser

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    body
    |> Parser.parse(channel)
    |> process_items(tuple |> NewBatch.set_timezone("UTC"))
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item)
    )
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, channel) do
    import ExPrintf

    sprintf(
      "%s/%s",
      [config.url_root, channel.grabber_info]
    )
  end
end
