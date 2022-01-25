defmodule Importer.Web.ViasatWorld do
  @moduledoc """
  Importer for ViasatWorld.
  """

  use Importer.Base.Periodic, type: "monthly"

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.Viasat, as: Parser

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    [_, _, timezone] =
      channel.grabber_info
      |> String.split(":")

    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone(timezone)
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
      |> NewBatch.add_airing(item)
    )
  end

  defp process(body) do
    body
    |> Parser.parse()
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    [year, month] = date |> to_string() |> String.split("-")
    [directory, name, timezone] = channel.grabber_info |> String.split(":")

    sprintf("%s/%s%s-%02d-%s-%s.xml", [
      config.url_root,
      directory,
      year,
      month |> String.to_integer(),
      name,
      timezone
    ])
  end
end
