defmodule Importer.Web.TV7 do
  @moduledoc """
  Importer for TV7 Channels.
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Parser.Xmltv

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  # TODO: PARSE EPISODE NO FROM TITLE
  @impl true
  def import_content(tuple, _batch, _channel, %{body: body} = _data) do
    body
    |> Okay.replace("<!DOCTYPE tv SYSTEM \"xmltv.dtd\">", "")
    |> Xmltv.parse()
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
  def object_to_url(_date, config, channel) do
    import ExPrintf

    [cid, lang] = channel.grabber_info |> String.split(":")

    sprintf(
      "%s/xmltv.xml?channel=%s&lang=%s&duration=3w",
      [
        config.url_root,
        cid,
        lang
      ]
    )
  end
end
