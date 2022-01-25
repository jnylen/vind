defmodule Importer.Web.KBSWorld do
  @moduledoc """
  Importer for KBS World.
  """

  use Importer.Base.Periodic, type: "weekly"
  use Importer.Helpers.Translation

  alias Importer.Helpers.Date, as: DateUtil
  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Parser.Helper

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    body
    |> process(channel)
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

  defp process(body, channel) do
    body
    |> clean_body()
    |> parse
    ~>> xpath(
      ~x"//tbody/tr"l,
      start_date: ~x".//td[1]/text()"S,
      start_time: ~x".//td[2]/text()"S,
      rerun: ~x".//td[4]/text()"S |> transform_by(&is_rerun?/1),
      content_title: ~x".//td[5]/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//td[9]/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//td[6]/text()"So |> transform_by(&Text.norm/1),
      subgenre: ~x".//td[7]/text()"So |> transform_by(&Text.norm/1),
      episode_num: ~x".//td[8]/text()"Io
    )
    |> Okay.map(&process_item(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item, channel) do
    %{
      start_time: parse_datetime(item[:start_date], item[:start_time]),
      descriptions:
        Text.convert_string(
          item[:content_description],
          List.first(channel.schedule_languages),
          "content"
        ),
      episode: item[:episode_num]
    }
    |> parse_title(item[:content_title], channel)
    |> add_qualifiers("rerun", item[:rerun])
  end

  defp add_qualifiers(airing, "live", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "live"
    )
  end

  defp add_qualifiers(airing, "rerun", true) do
    airing
    |> Helper.merge_list(
      :qualifiers,
      "rerun"
    )
  end

  defp add_qualifiers(airing, _, _), do: airing

  # Parse shit from a title
  defp parse_title(_, nil, _), do: nil

  defp parse_title(airing, title, channel) do
    season = Regex.named_captures(~r/Season (?<season>[0-9]+?)$/i, title)
    is_live = Regex.match?(~r/\[LIVE\]/i, title)

    new_title =
      title
      |> String.replace(~r/Season (?<season>[0-9]+?)$/i, "")
      |> String.replace(~r/\[LIVE\]/i, "")
      |> Text.norm()

    airing
    |> Map.put(
      :titles,
      Text.convert_string(
        new_title,
        List.first(channel.schedule_languages),
        "content"
      )
    )
    |> Map.put(:season, season["season"] |> Text.to_integer())
    |> add_qualifiers("live", is_live)
  end

  # Parses seperated fields of date and time into one.
  defp parse_datetime(date, time) do
    Timex.parse!("#{date |> parse_date()} #{time}", "%Y-%0m-%0d %H:%M", :strftime)
  end

  defp parse_date(date) do
    date
    |> Timex.parse!("%Y%0m%0d", :strftime)
    |> NaiveDateTime.to_date()
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, _channel) do
    import ExPrintf

    [year, week] = date |> to_string |> String.split("-")

    first_date =
      DateUtil.first_day_of_week(
        year |> String.to_integer(),
        week |> String.to_integer()
      )

    last_date =
      DateUtil.last_day_of_week(
        year |> String.to_integer(),
        week |> String.to_integer()
      )

    sprintf(
      "http://kbsworld.kbs.co.kr/schedule/down_schedule_db.php?down_time_add=-9&wlang=e&start_date=%s&end_date=%s",
      [first_date |> to_string(), last_date |> to_string()]
    )
  end

  defp clean_body(body) do
    ("<?xml version=\"1.0\" encoding=\"utf-8\"?>" <> body)
    |> Okay.replace(~r/\t+/, "")
    |> Okay.replace(~r/\n/, "")
    |> Okay.replace(~r/<style>(.*)<\/style>/, "")
    |> Okay.replace(~r/<colgroup>(.*)<\/colgroup>/, "")
    |> Okay.replace(~r/<thead>(.*)<\/thead>/, "")
    |> Okay.replace(~r/<\/body>/, "")
    |> Okay.replace(~r/<\/html>/, "")
    |> Okay.replace(~r/<table border="1" cellspacing="0" class="sch_table">/, "<table>")
    |> Okay.replace(~r/<br style='(.*?)'>/, "\n")
    |> Okay.replace(~r/&nbsp;/, "")
    |> Okay.replace(~r/&#39;/, "'")
    |> Okay.replace(~r/&#65533;/, "")
    |> Okay.replace(~r/ & /, " &amp; ")
  end

  defp is_rerun?("(R)"), do: true
  defp is_rerun?("R"), do: true
  defp is_rerun?(_), do: false
end
