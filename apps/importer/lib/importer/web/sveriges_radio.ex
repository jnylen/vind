defmodule Importer.Web.SverigesRadio do
  @moduledoc """
  Importer for SR Channels.
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch

  import Importer.Helpers.Xmltv

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  # TODO: PARSE EPISODE NO FROM TITLE
  @impl true
  def import_content(tuple, batch, channel, %{body: body} = _data) do
    body
    |> process(channel)
    |> process_items(
      tuple
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, _channel) do
    import ExPrintf

    sprintf("https://sverigesradio.se/xmltv/sr_%s.xml", [
      date |> to_string
    ])
  end
end
