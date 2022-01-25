defmodule Importer.Web.HRT do
  @moduledoc """
  Importer for HRT Channels.
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch

  import Importer.Helpers.Xmltv

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  # TODO: PARSE EPISODE NO FROM TITLE
  @impl true
  def import_content(tuple, _batch, _channel, %{body: body} = _data) do
    body
    |> process(nil, "weirdtz")
    |> process_items(tuple)
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
  def object_to_url(_date, _config, channel) do
    import ExPrintf

    sprintf("https://arhiv-raspored.hrt.hr/format/xmltv.xml?%s", [channel.grabber_info])
  end
end
