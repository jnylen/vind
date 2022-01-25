defmodule Importer.Web.VIMN do
  @moduledoc """
  Importer for VIMN.

  For their new exports
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Parser.Xmltv, as: Parser

  require OK
  use OK.Pipe

  # if a channel has any of these langs in the
  # schedule languages we will remove the descriptions
  @vgmedia_langs ["de"]

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, channel, %{body: body} = _data) do
    body
    |> process(channel)
    |> batch_em(
      tuple
      |> NewBatch.set_timezone("UTC")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process(body, channel) do
    if channel |> remove_descriptions?() do
      body
      |> Parser.parse(channel)
      |> Okay.filter(fn x ->
        Map.get(x, :titles, []) != []
      end)
      |> Okay.map(fn airing ->
        airing
        |> Map.delete(:descriptions)
        |> Map.delete(:end_time)
      end)
      |> OK.wrap()
    else
      body
      |> Parser.parse(channel)
      |> Okay.filter(fn x ->
        Map.get(x, :titles, []) != []
      end)
      |> Okay.map(fn airing ->
        airing
        |> Map.delete(:end_time)
      end)
      |> OK.wrap()
    end
  end

  defp remove_descriptions?(%{schedule_languages: langs}) do
    Enum.any?(langs, fn lang ->
      Enum.member?(@vgmedia_langs, lang)
    end)
  end

  defp remove_descriptions?(_), do: false

  defp batch_em({:error, reason}, _), do: {:error, reason}
  defp batch_em(_, {:error, reason}), do: {:error, reason}

  defp batch_em({:ok, []}, tuple), do: tuple

  defp batch_em({:ok, [item | items]}, tuple) do
    batch_em(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    [slug, lang_code] = channel.grabber_info |> String.split(":")

    sprintf("%s/%s/xmltvlegal/%s/%s.xml", [
      config.url_root,
      slug,
      lang_code,
      date |> to_string() |> String.replace("-", "")
    ])
  end
end
