defmodule Importer.Web.DR do
  @moduledoc """
  Importer for Swedish State TV
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.{NewBatch, Text}
  alias Importer.Parser.{TVAnytime, Helper}
  alias Shared.HttpClient

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  # TODO: PARSE EPISODE NO FROM TITLE
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
        |> process_item()
        |> TVAnytime.remove_episode?()
      )
    )
  end

  # Parse shit from the descriptions
  def process_item(item) do
    item
    |> Map.get(:titles, [])
    |> Enum.map(& &1.value)
    |> Enum.reduce(item |> Map.delete(:titles), fn x, acc ->
      acc |> parse_title(x)
    end)
  end

  # Try to find if the last part of the title is a roman numeral.
  # If it is then its a season.
  defp parse_title(airing, title) do
    # Grab last part of title
    regexp = ~r/\s+(?<numeral>[ixvlcdm]+?)$/i

    # Replace (xx:xx) and (xx) with nothing
    title =
      title
      |> String.replace(~r/\(((\d+)|(\d+\:\d+)?)\)$/u, "")
      |> Text.norm()

    if Regex.match?(regexp, title) do
      %{"numeral" => numeral} = Regex.named_captures(regexp, title)

      new_title =
        String.replace(title, numeral, "")
        |> Text.norm()

      # Try to decode
      case Roman.decode(numeral) do
        {:ok, season_number} ->
          airing
          |> Helper.merge_list(
            :titles,
            Text.convert_string(new_title, "da", "content")
          )
          |> Map.put(:season, season_number)

        _ ->
          airing
          |> Helper.merge_list(
            :titles,
            Text.convert_string(new_title, "da", "content")
          )
      end
    else
      airing
      |> Helper.merge_list(
        :titles,
        Text.convert_string(title, "da", "content")
      )
    end
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    sprintf("https://api.dr.dk/epg/api/schedules/%s/%s", [
      channel.grabber_info,
      date
    ])
  end

  @impl true
  def http_client(config, _folder),
    do:
      HttpClient.init(%{
        headers: %{
          "APIkey" => config.api_key,
          "Accept" => "application/xml"
        },
        cookie_jar: CookieJar.new()
      })
end
