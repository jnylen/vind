defmodule Importer.Parser.TVN do
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser
  alias Importer.Helpers.Word, as: WordHelper
  alias Importer.Parser.Helper

  import Meeseeks.CSS

  def parse(file_name, channel) do
    texts =
      file_name
      |> WordHelper.parse_docx()
      |> String.trim_leading(<<0xFEFF::utf8>>)
      |> Helper.fix_known_errors()
      |> String.replace("<br />", ";;;;;")
      |> Meeseeks.all([css("strong"), css("tr")])

    []
    |> parse_text(texts, channel)

    #nil
  end

  # Parse texts
  defp parse_text(list, [], _), do: list |> Enum.reverse() |> OK.wrap()

  defp parse_text(list, [string | strings], channel) do
    text = Meeseeks.text(string)

    cond do
      is_date?(text) ->
        {:ok, date} = text |> parse_date()

        [{"date", date} | list]
        |> parse_text(strings, channel)

      is_show?(text) ->
        {:ok, airing} = parse_show(string)

        [{"airing", airing} | list]
        |> parse_text(strings, channel)

      true ->
        list
        |> parse_text(strings, channel)
    end
  end

  # is a date?
  defp is_date?(string) do
    Regex.match?(
      ~r/^(.*?), (.*?), (\d{4})-(\d{2})-(\d{2})$/i,
      string
    )
  end

  defp parse_date(string) do
    case Regex.named_captures(
           ~r/^(.*?), (.*?), (?<date>\d{4}-\d{2}-\d{2})$/i,
           string
         ) do
      %{
        "date" => date
      } ->
        DateTimeParser.parse_date(date)

      _ ->
        nil
    end
  end

  # Is a show?
  defp is_show?(string) do
    Regex.match?(~r/^(\d\d)\:(\d\d)\s+(.*)$/i, string)
  end

  defp parse_show(string) do
    strings =
      Meeseeks.all(string, [css("p")])
      |> Enum.map(&Meeseeks.text/1)
      |> Enum.map(&String.split(&1, ";;;;;"))
      |> List.flatten()

    start_time = strings |> List.first()
    title = strings |> List.delete_at(0) |> List.first()

    desc =
      strings
      |> List.delete_at(0)
      |> List.delete_at(0)
      |> TextParser.join_text()
      |> Text.convert_string("pl", "content")

    case Regex.named_captures(~r/(?<title>.*)\s+\-\s+(?<subtitle>.*)$/i, title) do
      %{
        "subtitle" => subtitle,
        "title" => title
      } ->
        %{
          start_time: start_time |> String.replace(".", ":")
        }
        |> parse_title(title |> String.replace(start_time, ""))
        |> parse_subtitle(subtitle)

      _ ->
        %{
          start_time: start_time |> String.replace(".", ":")
        }
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            title |> Text.norm(),
            "pl",
            "content"
          )
        )
    end
    |> Map.put(:descriptions, desc)
    |> OK.wrap()
  end

  def parse_title(airing, title) do
    {:ok, details} =
      title
      |> title_regex()

    airing
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        Map.get(details, "title") |> Text.norm(),
        "pl",
        "content"
      )
    )
    |> TextParser.put_non_nil(:episode, Text.to_integer(details["episode_num"]))
    |> TextParser.put_non_nil(:season, Text.to_integer(details["season_num"]))
    |> TextParser.put_non_nil(:qualifiers, details["qualifiers"])
    |> TextParser.put_non_nil(:real_title, title)
  end

  def parse_subtitle(airing, subtitle) do
    results =
      subtitle
      |> split_text()
      |> Okay.map(fn string ->
        case subtitle_regex(string) do
          {:error, _} -> {string, %{}}
          {:ok, result} -> {nil, result}
        end
      end)

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:credits, parse_credits(result["actors"], "actor"))
          |> TextParser.put_non_nil(:credits, parse_credits(result["directors"], "director"))
          |> TextParser.put_non_nil(:qualifiers, result["qualifiers"])
          |> TextParser.put_non_nil(:program_type, result["program_type"])

        {result, TextParser.merge_with_lists(acc, new_result)}
      end)

    airing
    |> TextParser.merge_with_lists(result)
  end

  defp title_regex(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)\((?<season_num>\d+)\)\((?<episode_num>\d+)\/(?<of_episodes>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)\((?<season_num>\d+)\)\s+\((?<episode_num>\d+)\/(?<of_episodes>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)(?<season_num>\d+)\((?<episode_num>\d+)\/(?<of_episodes>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)(?<season_num>\d+)\s+\((?<episode_num>\d+)\/(?<of_episodes>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)\((?<episode_num>\d+)\/(?<of_episodes>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*?)\((?<episode_num>\d+)\)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/(?<title>.*)/i,
      %{}
    )
    |> StringMatcher.match_captures(string)
  end

  defp subtitle_regex(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/^obsada: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^reżyseria: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Dolby\.$/i,
      %{"qualifiers" => ["DD 5.1"]}
    )
    |> StringMatcher.add_regexp(
      ~r/^live\.$/i,
      %{"qualifiers" => ["live"]}
    )
    |> StringMatcher.add_regexp(
      ~r/^program\s+/i,
      %{"program_type" => "series"}
    )
    |> StringMatcher.add_regexp(
      ~r/^film\s+/i,
      %{"program_type" => "movie"}
    )
    |> StringMatcher.match_captures(string)
  end

  defp parse_credits("", _), do: []
  defp parse_credits(nil, _), do: []

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(~r/,/i)
    |> Okay.map(fn person ->
      %{
        person:
          person
          |> Text.norm()
          |> string_replace(~r/\.$/, "")
          |> Text.norm(),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  # Custom split_ext
  def split_text(nil), do: []
  def split_text(""), do: []

  ## Not working completely.
  def split_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.replace(~r/\x2e/, ".")
    |> String.replace(~r/\r/, ", ")
    |> String.replace(~r/([\?\!])\./, "\\g{1}")
    |> String.replace(~r/\.{3,}/, "::.")
    |> String.replace(~r/Dolby/, ";;Dolby")
    # |> String.replace(~r/,/, ";;")
    |> String.replace(~r/,(\w+):/ui, ";;\\g{1}:")
    #|> String.replace(~r/([A-Z\:]+?)\s+([A-Z\:]?)/, ";;\\g{2}")
    |> String.replace(~r/([\.\!\?])\s+([\(A-Z���])/, "\\g{1};;\\g{2}")
    |> String.trim()
    |> String.split(";;")
    |> Enum.map(fn string ->
      case Regex.match?(~r/[\.\!\?]$/, string) do
        false -> String.trim(string) <> "."
        true -> string
      end
    end)
  end

  def split_text(_), do: nil

  defp string_replace(nil, _regex, _replace), do: nil
  defp string_replace("", _regex, _replace), do: nil
  defp string_replace(string, regex, replace), do: String.replace(string, regex, replace)
end
