defmodule Importer.Parser.TVAnytimeTiny do
  @moduledoc """
  XML Saxy Parser for the TVAnytime. Tiny version.
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper

  def parse(incoming, channel \\ nil)

  def parse(nil, _), do: {:error, "incoming value is nil."}

  def parse({:ok, incoming}, channel), do: parse(incoming, channel)
  def parse({:error, reason}, _), do: {:error, reason}

  def parse(%File.Stream{} = stream, channel) when is_map(stream) do
    stream
    |> Stream.filter(&(&1 != "\n"))
    |> Stream.map(&Helper.fix_known_errors/1)
    |> Saxy.parse_stream(__MODULE__, {nil, nil, [], channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> Saxy.parse_string(__MODULE__, {nil, nil, [], channel})
  end

  def parse(_, _), do: {:error, "needs to be a File stream"}

  # Start and end document
  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, _, airings, _}) do
    {:ok, airings |> Helper.sort_by_start_time()}
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {airing, %{text_key: _}, airings, channel}) do
    handle_event(:start_element, {key, attributes}, {airing, nil, airings, channel})
  end

  ########################################################################

  ######### AIRING

  # Start of an airing
  def handle_event(
        :start_element,
        {"ProgramInformation", _},
        {nil, _, airings, channel}
      ) do
    {:ok, {%{}, nil, airings, channel}}
  end

  ## Push to map
  def handle_event(:end_element, "ProgramInformation", {nil, _, airings, channel}),
    do: {:ok, {nil, nil, airings, channel}}

  def handle_event(:end_element, "ProgramInformation", {item, _, airings, channel}),
    do: {:ok, {nil, nil, [item | airings], channel}}

  ######### DATETIMES

  # Start time
  def handle_event(:start_element, {"PublishedStartTime", _}, {item, _, airings, channel}),
    do: {:ok, {item, "start_time", airings, channel}}

  def handle_event(:characters, chars, {item, "start_time", airings, channel}) do
    new_item =
      item
      |> Map.put_new(:start_time, chars |> parse_datetime(channel))

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "PublishedStartTime", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # Start time
  def handle_event(:start_element, {"PublishedEndTime", _}, {item, _, airings, channel}),
    do: {:ok, {item, "end_time", airings, channel}}

  def handle_event(:characters, chars, {item, "end_time", airings, channel}) do
    new_item =
      item
      |> Map.put_new(:end_time, chars |> parse_datetime(channel))

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "PublishedEndTime", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ######### TITLE
  def handle_event(:start_element, {"Title", attributes}, {item, _, airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    {:ok,
     {item, {"title", attrs |> Map.get("type"), attrs |> Map.get("xml:lang")}, airings, channel}}
  end

  def handle_event(:characters, chars, {item, {"title", "main", language}, airings, channel}) do
    new_item =
      item
      |> parse_title(chars |> Text.norm(), language, channel)

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {item, {"title", "EpisodeTitle", language}, airings, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        :subtitles,
        Text.string_to_map(
          chars |> Text.norm(),
          language |> parse_lang(),
          "content"
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "Title", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ######### Synopsis
  def handle_event(:start_element, {"Synopsis", attributes}, {item, _, airings, channel}),
    do:
      {:ok,
       {item, {"synopsis", attributes |> Enum.into(%{}) |> Map.get("xml:lang")}, airings, channel}}

  def handle_event(:characters, chars, {item, {"synopsis", language}, airings, channel}) do
    new_item =
      item
      |> Helper.merge_list(
        :descriptions,
        Text.string_to_map(
          chars |> Text.norm(),
          language |> parse_lang(),
          "content"
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "Synopsis", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ######### Genre
  def handle_event(:start_element, {"Genre", attributes}, {item, _, airings, channel}),
    do:
      {:ok, {item, {"genre", attributes |> Enum.into(%{}) |> Map.get("type")}, airings, channel}}

  def handle_event(:characters, chars, {item, {"genre", "main"}, airings, channel}) do
    new_item =
      item
      |> append_categories(
        Translation.translate_category(
          "TVAnytime_genre",
          chars |> Text.norm()
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "Genre", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ######### EpisodeNumber
  def handle_event(:start_element, {"EpisodeNumber", _}, {item, _, airings, channel}),
    do: {:ok, {item, "episode", airings, channel}}

  def handle_event(:characters, chars, {item, "episode", airings, channel}) do
    new_item =
      item
      |> Map.put(:episode, chars |> String.to_integer())

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "EpisodeNumber", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ######### SeasonNumber
  def handle_event(:start_element, {"SeasonNumber", _}, {item, _, airings, channel}),
    do: {:ok, {item, "season", airings, channel}}

  def handle_event(:characters, chars, {item, "season", airings, channel}) do
    new_item =
      item
      |> Map.put(:season, chars |> String.to_integer())

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "SeasonNumber", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  ########################################################################

  # In case missing
  # Might fuck up credit parsing
  def handle_event(:end_element, _name, {airing, _, airings, channel}) do
    {:ok, {airing, nil, airings, channel}}
  end

  def handle_event(:start_element, {_name, _attributes}, state) do
    {:ok, state}
  end

  def handle_event(:end_element, _name, state) do
    {:ok, state}
  end

  def handle_event(:characters, _chars, state), do: {:ok, state}

  ########

  defp parse_title(airing, chars, language, _channel) do
    cond do
      Regex.match?(~r/(Episode|EP) (?<episode_num>\d+) - (?<subtitle>.*?)$/i, chars) ->
        matches =
          Regex.named_captures(
            ~r/(?<title>.*)(Episode|EP) (?<episode_num>\d+) - (?<subtitle>.*?)$/i,
            chars
          )

        airing
        |> Map.put(:episode, Map.get(matches, "episode_num") |> str_to_int())
        |> Helper.merge_list(
          :subtitles,
          Text.string_to_map(
            Map.get(matches, "subtitle") |> prettify_text(),
            language |> parse_lang(),
            "content"
          )
        )
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            Map.get(matches, "title") |> prettify_text(),
            language |> parse_lang(),
            "content"
          )
        )

      Regex.match?(~r/(Episode|EP) (?<episode_num>\d+)$/i, chars) ->
        matches = Regex.named_captures(~r/(?<title>.*)(Episode|EP) (?<episode_num>\d+)$/i, chars)

        airing
        |> Map.put(:episode, Map.get(matches, "episode_num") |> str_to_int())
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            Map.get(matches, "title") |> prettify_text(),
            language |> parse_lang(),
            "content"
          )
        )

      true ->
        airing
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            chars |> prettify_text(),
            language |> parse_lang(),
            "content"
          )
        )
    end
  end

  defp str_to_int(nil), do: nil
  defp str_to_int(str), do: str |> String.to_integer()

  defp parse_datetime(string, channel) do
    case DateTimeParser.parse_datetime(string) do
      {:ok, datetime} ->
        datetime
        |> Timex.to_datetime(Map.get(channel, :grabber_info, "Europe/Berlin"))
        |> Timex.Timezone.convert("UTC")

      _ ->
        nil
    end
  end

  defp parse_lang(nil), do: nil
  defp parse_lang("eng"), do: "en"
  defp parse_lang("swe"), do: "sv"
  defp parse_lang(val), do: val |> String.downcase()

  defp prettify_text(text) do
    text
    |> Text.norm()
    |> String.replace(~r/\-$/i, "")
    |> Text.norm()
  end
end
