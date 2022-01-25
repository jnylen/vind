defmodule Importer.Helpers.Xmltv do
  @moduledoc """
  An XMLTV-file Helper.
  """
  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Helpers.Okay
  use Importer.Helpers.Translation

  require OK
  use OK.Pipe

  @doc """
  Parse an XML string in the XMLTV format
  """
  def process(body, channel \\ nil, time_format \\ "%Y%0m%0d%H%M%S %z")

  def process({:ok, body}, channel, time_format), do: process(body, channel, time_format)
  def process({:error, reason}, _, _), do: {:error, reason}

  def process(body, channel, time_format) do
    OK.for do
      parsed_body <- process_body(body, channel, time_format)

      airings =
        parsed_body
        |> Okay.sort(&(&1.start_time < &2.start_time))
        |> Okay.to_list()
    after
      airings
    end
  end

  defp process_body(body, channel, time_format) do
    body
    |> parse
    ~>> xpath(
      ~x"//programme"l,
      air_start_time: ~x".//@air_time_start"S |> transform_by(&clean_timestamp/1),
      air_end_time: ~x".//@air_time_end"S |> transform_by(&clean_timestamp/1),
      start_time: ~x".//@start"S |> transform_by(&clean_timestamp/1),
      end_time: ~x".//@stop"S |> transform_by(&clean_timestamp/1),
      titles: [
        ~x"./title"l,
        language: ~x"./@lang"S |> transform_by(&Text.norm/1),
        value: ~x"./text()"S |> transform_by(&Text.norm/1)
      ],
      subtitles: [
        ~x"./sub-title"lo,
        language: ~x"./@lang"S |> transform_by(&Text.norm/1),
        value: ~x"./text()"S |> transform_by(&Text.norm/1)
      ],
      descriptions: [
        ~x"./desc"lo,
        language: ~x"./@lang"S |> transform_by(&Text.norm/1),
        value: ~x"./text()"S |> transform_by(&Text.norm/1)
      ],
      categories: ~x".//category/text()"lS,
      directors: ~x".//credits/director/text()"lS,
      presenters: ~x".//credits/presenter/text()"lS,
      guests: ~x".//credits/guest/text()"lS,
      actors: ~x".//credits/actor/text()"lS,
      production_countries: ~x".//country/text()"lS,
      production_year: ~x".//date/text()"S,
      episode_text: ~x".//episode-num[@system='onscreen']/text()"So |> transform_by(&Text.norm/1),
      episode_num: ~x".//episode-num[@system='xmltv_ns']/text()"So |> transform_by(&Text.norm/1),
      channel: ~x".//@channel"So |> transform_by(&Text.norm/1)
    )
    |> Okay.reject(
      &correct_channel?(
        &1.channel,
        if(channel && channel.grabber_info, do: channel.grabber_info, else: nil)
      )
    )
    |> Okay.map(&process_item(&1, channel, time_format))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Apparently some channels have "tabs"?!
  defp clean_timestamp(""), do: nil
  defp clean_timestamp(nil), do: nil

  defp clean_timestamp(string) do
    string
    |> Okay.replace(" ", " ")
    |> Text.norm()
  end

  # Reject any channel that isnt the one wanted
  defp correct_channel?(_, nil), do: false
  defp correct_channel?(airing, grabber_info) when airing != grabber_info, do: true
  defp correct_channel?(_, _), do: false

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item, channel, time_format) do
    # IO.inspect(item)

    # title = Meeseeks.one(item, xpath("//title"))

    %{
      start_time: parse_datetime(item[:air_start_time] || item[:start_time], time_format),
      end_time: parse_datetime(item[:air_end_time] || item[:end_time], time_format),
      titles: process_strings(channel, item[:titles]),
      subtitles: process_strings(channel, item[:subtitles]),
      descriptions: process_strings(channel, item[:descriptions]),
      credits: parse_credits(item)
    }
    |> append_countries(
      Translation.translate_country(
        "xmltv",
        item[:production_countries]
      )
    )
    |> append_categories(
      Translation.translate_category(
        "xmltv",
        item[:categories]
      )
    )

    # ARRAY
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 20181214020000 +0100
  defp parse_datetime(nil, _), do: nil

  defp parse_datetime(datetime_string, "weirdtz") do
    if Regex.match?(~r/\+000$/, datetime_string) do
      datetime_string
      |> Okay.replace(" +000", "")
      |> Timex.parse!("%Y%0m%0d%H%M%S", :strftime)
      |> Timex.set(second: 00)
      |> Timex.Timezone.convert("UTC")
    else
      datetime_string
      |> Timex.parse!("%Y%0m%0d%H%M%S %z", :strftime)
      |> Timex.set(second: 00)
      |> Timex.Timezone.convert("UTC")
    end
  end

  defp parse_datetime(datetime_string, time_format) do
    datetime_string
    |> Timex.parse!(time_format, :strftime)
    |> Timex.set(second: 00)
    |> Timex.Timezone.convert("UTC")
  end

  defp process_strings(_, []), do: []

  defp process_strings(channel, [%{} = string | strings]) do
    Text.convert_string(
      string[:value],
      string[:language] || if(is_nil(channel), do: nil, else: channel.schedule_language),
      "content"
    ) ++ process_strings(channel, strings)
  end

  defp parse_credits(item) do
    (add_credits("director", item.directors) ++
       add_credits("presenter", item.presenters) ++
       add_credits("guest", item.guests) ++ add_credits("actor", item.actors))
    |> List.flatten()
  end

  defp add_credits(_, nil), do: []

  defp add_credits(type, [credit | credits]) do
    [
      %{
        type: type,
        person: credit |> Text.norm()
      }
    ] ++ add_credits(type, credits)
  end

  defp add_credits(_, []), do: []

  def parse_xmltv_ns(""), do: %{}
  def parse_xmltv_ns(nil), do: %{}

  def parse_xmltv_ns(string) do
    [season, all_episode, _] = String.split(string, ".")

    episode = all_episode |> String.split("/")

    %{
      value: string,
      season: season |> Text.to_integer() |> add_one(),
      episode: Enum.at(episode, 0) |> Text.to_integer() |> add_one(),
      of_episode: Enum.at(episode, 1) |> Text.to_integer()
    }
  end

  defp add_one(""), do: nil
  defp add_one(nil), do: nil
  defp add_one(int) when is_integer(int), do: int + 1
end
