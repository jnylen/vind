defmodule Importer.Web.NRK do
  @moduledoc """
  Importer for Swedish State TV
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.TVAnytime

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, channel, %{body: body} = _data) do
    body
    |> TVAnytime.parse(channel)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("UTC")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> Map.delete(:end_time)
        |> Map.delete(:images)
      )
    )
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    sprintf("https://www.nrk.no/tvanytime/xml/TVANordig%s%s.xml", [
      String.replace(date, "-", ""),
      channel.grabber_info
    ])
  end
end
