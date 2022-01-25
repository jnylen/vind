defmodule Importer.Parser.GlobalListings.Word do
  alias Importer.Helpers.Text
  alias Importer.Helpers.Word, as: WordHelper
  alias Importer.Parser.Helper

  import Meeseeks.CSS

  @translations %{
    "sv" => %{
      "januari" => 1,
      "februari" => 2,
      "mars" => 3,
      "april" => 4,
      "maj" => 5,
      "juni" => 6,
      "juli" => 7,
      "augusti" => 8,
      "september" => 9,
      "oktober" => 10,
      "november" => 11,
      "december" => 12
    },
    "en" => %{
      "january" => 1,
      "february" => 2,
      "march" => 3,
      "april" => 4,
      "may" => 5,
      "june" => 6,
      "july" => 7,
      "august" => 8,
      "september" => 9,
      "october" => 10,
      "november" => 11,
      "december" => 12
    },
    "da" => %{
      "januar" => 1,
      "februar" => 2,
      "marts" => 3,
      "april" => 4,
      "maj" => 5,
      "juni" => 6,
      "juli" => 7,
      "august" => 8,
      "september" => 9,
      "oktober" => 10,
      "november" => 11,
      "december" => 12
    },
    "nb" => %{
      "januar" => 1,
      "februar" => 2,
      "mars" => 3,
      "april" => 4,
      "mai" => 5,
      "juni" => 6,
      "juli" => 7,
      "august" => 8,
      "september" => 9,
      "oktober" => 10,
      "november" => 11,
      "desember" => 12
    }
  }

  def parse(file_name, channel) do
    texts =
      file_name
      |> WordHelper.parse()
      |> String.trim_leading(<<0xFEFF::utf8>>)
      |> Helper.fix_known_errors()
      |> String.replace("<b>", "")
      |> String.replace("</b>", "")
      |> String.replace("<font color=\"Black\">", "")
      |> String.replace("</font>", "")
      |> Meeseeks.all(css("div"))
      |> into_text()

    []
    |> parse_text(texts, channel)
  end

  # Just turn it into a text instead
  defp into_text([]), do: []

  defp into_text([string | strings]) do
    [Meeseeks.text(string) | into_text(strings)]
  end

  # Parse texts
  defp parse_text(list, [], _), do: list |> Enum.reverse() |> OK.wrap()

  defp parse_text(list, [string | strings], channel) do
    language = Map.get(channel, :schedule_languages) |> List.first()

    cond do
      is_date?(string, language) ->
        {:ok, date} = string |> parse_date(language)

        [{"date", date} | list]
        |> parse_text(strings, channel)

      is_show?(string, language) ->
        {:ok, airing} = parse_show(string, language)

        [{"airing", airing} | list]
        |> parse_text(strings, channel)

      true ->
        list
        |> parse_text(strings, channel)
    end
  end

  #### FIND A DATE
  # Danish - Tirsdag 1. oktober 2019
  defp is_date?(string, "da") do
    Regex.match?(
      ~r/^(mandag|tirsdag|onsdag|torsdag|fredag|lørdag|søndag)\s*\d+\.\s*\D+\s*\d+$/i,
      string
    )
  end

  # Norwegian - søndag 1. september, 2019
  defp is_date?(string, "nb") do
    Regex.match?(
      ~r/^(mandag|tirsdag|onsdag|torsdag|fredag|lørdag|søndag)\s*\d+\.\s*\D+(,|)\s*\d+$/i,
      string
    )
  end

  # Swedish - Tisdag 1 oktober 2019
  defp is_date?(string, "sv") do
    Regex.match?(
      ~r/^(måndag|tisdag|onsdag|torsdag|fredag|lördag|söndag)\s*\d+\s*\D+\s*\d+$/i,
      string
    )
  end

  # English - Tuesday 1 october 2019
  defp is_date?(string, "en") do
    Regex.match?(
      ~r/^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s*\d+\s*\D+\s*\d+$/i,
      string
    )
  end

  defp is_date?(_, _), do: false

  defp parse_date(string, "da") do
    case Regex.named_captures(
           ~r/^(mandag|tirsdag|onsdag|torsdag|fredag|lørdag|søndag)\s*(?<day>\d+)\.\s*(?<month_name>\D+)\s*(?<year>\d+)$/i,
           string
         ) do
      %{
        "day" => day,
        "month_name" => month_name,
        "year" => year
      } ->
        into_date(year, fetch_month(month_name, "da"), day)

      _ ->
        nil
    end
  end

  defp parse_date(string, "nb") do
    case Regex.named_captures(
           ~r/^(mandag|tirsdag|onsdag|torsdag|fredag|lørdag|søndag)\s*(?<day>\d+)\.\s*(?<month_name>\D+)(,|)\s*(?<year>\d+)$/i,
           string
         ) do
      %{
        "day" => day,
        "month_name" => month_name,
        "year" => year
      } ->
        into_date(year, fetch_month(month_name, "nb"), day)

      _ ->
        nil
    end
  end

  defp parse_date(string, "sv") do
    case Regex.named_captures(
           ~r/^(måndag|tisdag|onsdag|torsdag|fredag|lördag|söndag)\s*(?<day>\d+)\s*(?<month_name>\D+)\s*(?<year>\d+)$/i,
           string
         ) do
      %{
        "day" => day,
        "month_name" => month_name,
        "year" => year
      } ->
        into_date(year, fetch_month(month_name, "sv"), day)

      _ ->
        nil
    end
  end

  defp parse_date(string, "en") do
    case Regex.named_captures(
           ~r/^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s*(?<day>\d+)\s*(?<month_name>\D+)\s*(?<year>\d+)$/i,
           string
         ) do
      %{
        "day" => day,
        "month_name" => month_name,
        "year" => year
      } ->
        into_date(year, fetch_month(month_name, "en"), day)

      _ ->
        nil
    end
  end

  #### FIND A SHOW
  defp is_show?(string, "en") do
    Regex.match?(~r/^(\d\d)\:(\d\d)(.*)$/i, string)
  end

  defp is_show?(string, _) do
    Regex.match?(~r/^(\d\d)\.(\d\d)\s+(.*)$/i, string)
  end

  # defp is_show?(_, _), do: false

  defp parse_show(string, "en") do
    case Regex.named_captures(~r/^(?<start_time>\d\d\:\d\d)(?<title>.*)$/i, string) do
      %{
        "start_time" => start_time,
        "title" => title
      } ->
        %{
          start_time: start_time
        }
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            title |> Text.norm(),
            "en",
            "content"
          )
        )
        |> OK.wrap()

      _ ->
        {:error, "couldn't parse show"}
    end
  end

  defp parse_show(string, language) do
    case Regex.named_captures(~r/^(?<start_time>\d\d\.\d\d)\s+(?<title>.*)$/i, string) do
      %{
        "start_time" => start_time,
        "title" => title
      } ->
        case Regex.named_captures(~r/(?<title>.*)\:\s+(?<subtitle>.*)$/i, title) do
          %{
            "subtitle" => subtitle,
            "title" => title
          } ->
            %{
              start_time: start_time |> String.replace(".", ":")
            }
            |> Helper.merge_list(
              :titles,
              Text.string_to_map(
                title |> Text.norm(),
                language,
                "content"
              )
            )
            |> Helper.merge_list(
              :subtitles,
              Text.string_to_map(
                subtitle |> Text.norm(),
                language,
                "content"
              )
            )

          _ ->
            %{
              start_time: start_time |> String.replace(".", ":")
            }
            |> Helper.merge_list(
              :titles,
              Text.string_to_map(
                title |> Text.norm(),
                language,
                "content"
              )
            )
        end
        |> OK.wrap()

      _ ->
        {:error, "couldn't parse show"}
    end
  end

  defp fetch_month(month_name, language) do
    Map.get(@translations, language, %{})
    |> Map.get(month_name |> String.trim() |> String.downcase())
  end

  defp into_date(_, nil, _), do: {:error, "couldn't fetch date"}

  defp into_date(year, month, day) do
    {year |> String.to_integer(), month, day |> String.to_integer()}
    |> Date.from_erl()
  end
end
