defmodule Importer.Web.TVNow do
  @moduledoc """
  Importer for RTL channels.
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Berlin"),
      channel
    )
  end

  defp process_items({:error, reason}, _, _), do: {:error, reason}
  defp process_items(_, {:error, reason}, _), do: {:error, reason}

  defp process_items({:ok, []}, tuple, _), do: tuple

  defp process_items({:ok, [item | items]}, tuple, channel) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      channel
    )
  end

  defp process(body) do
    body
    |> Jsonrs.decode()
    |> Okay.get("items", [])
    |> Okay.map(&process_item(&1))
    |> Importer.Parser.Helper.sort_by_start_time()
    |> OK.wrap()
  end

  defp process_item(item) do
    %{
      start_time: item["startDate"] |> parse_datetime(),
      # end_time: item["endDate"] |> parse_datetime(),
      titles: Text.convert_string(item["title"] |> Text.norm(), "de", "content"),
      season: item["season"],
      episode: item["episode"]
    }
    |> calculate_type(item)
  end

  defp calculate_type(airing, item) do
    diff_in_mins =
      diff_times(
        item["endDate"],
        item["startDate"]
      )

    cond do
      # Folge 19: 'Pilot'
      Regex.match?(~r/^Folge (\d+)\: \'(.*?)\'$/i, item["subTitle"]) ->
        [episode_num, subtitle] =
          Regex.run(~r/^Folge (\d+)\: \'(.*?)\'$/i, item["subTitle"], capture: :all_but_first)

        airing
        |> Map.put(:episode, episode_num |> String.to_integer())
        |> Map.put(:subtitles, Text.convert_string(subtitle |> Text.norm(), "de", "content"))
        |> Map.put(:program_type, "series")

      # Folge 19: Pilot
      Regex.match?(~r/^Folge (\d+)\: (.*?)$/i, item["subTitle"]) ->
        [episode_num, subtitle] =
          Regex.run(~r/^Folge (\d+)\: (.*?)$/i, item["subTitle"], capture: :all_but_first)

        airing
        |> Map.put(:episode, episode_num |> String.to_integer())
        |> Map.put(:subtitles, Text.convert_string(subtitle |> Text.norm(), "de", "content"))
        |> Map.put(:program_type, "series")

      # Folge 19
      Regex.match?(~r/^Folge (\d+)$/i, item["subTitle"]) ->
        [episode_num] = Regex.run(~r/^Folge (\d+)$/i, item["subTitle"], capture: :all_but_first)

        airing
        |> Map.put(:episode, episode_num |> String.to_integer())
        |> Map.put(:program_type, "series")

      # 'Pilot'
      Regex.match?(~r/^\'(.*?)\'$/i, item["subTitle"]) ->
        [subtitle] = Regex.run(~r/^\'(.*?)\'$/i, item["subTitle"], capture: :all_but_first)

        airing
        |> Map.put(:subtitles, Text.convert_string(subtitle |> Text.norm(), "de", "content"))
        |> Map.put(:program_type, "series")

      # Pilot
      !is_blank?(item["subTitle"]) ->
        airing
        |> Map.put(
          :subtitles,
          Text.convert_string(item["subTitle"] |> Text.norm(), "de", "content")
        )
        |> Map.put(:program_type, "series")

      # Movie?
      diff_in_mins > 90 && !is_nil(item["movie"]) && is_blank?(item["epgFormat"]["defaultImage"]) ->
        airing
        |> Map.put(:program_type, "movie")

      true ->
        airing
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) do
    datetime_string
    |> DateTimeParser.parse_datetime()
    |> case do
      {:ok, val} -> val
      {:error, _} -> nil
      _ -> nil
    end
  end

  defp is_blank?(""), do: true
  defp is_blank?(nil), do: true
  defp is_blank?(val), do: val |> is_nil()

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    sprintf(
      "%s/%s/%s?fields=%s",
      [
        config.url_root,
        channel.grabber_info,
        date |> to_string(),
        "*,movie.*,movie.format,movie.paymentPaytypes,movie.pictures,movie.trailers,epgImages,epgImages.*,epgFormat,*.*"
      ]
    )
  end

  defp diff_times(nil, _), do: 0
  defp diff_times(_, nil), do: 0

  defp diff_times(stop, start) do
    Timex.diff(
      stop |> parse_datetime(),
      start |> parse_datetime(),
      :minutes
    )
  end
end
