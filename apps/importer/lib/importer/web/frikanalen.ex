defmodule Importer.Web.Frikanalen do
  @moduledoc """
  Importer for DigiTV Channels.
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch

  import Importer.Helpers.Xmltv

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, channel, %{body: body} = _data) do
    body
    |> process(channel |> Map.put(:grabber_info, nil))
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

    [year, month, day] = date |> to_string() |> String.split("-")

    sprintf("https://frikanalen.no/xmltv/%d/%02d/%02d", [
      year |> String.to_integer(),
      month |> String.to_integer(),
      day |> String.to_integer()
    ])
  end
end
