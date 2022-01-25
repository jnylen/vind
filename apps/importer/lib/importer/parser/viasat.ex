defmodule Importer.Parser.Viasat do
  @moduledoc """
  XML Saxy Parser for the old Viasat XML format that is used by Viasat World and AMB.
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper

  def parse(incoming, channel \\ nil)

  def parse(nil, _), do: {:error, "incoming value is nil."}

  def parse({:ok, incoming}, channel), do: parse(incoming, channel)
  def parse({:error, reason}, _), do: {:error, reason}

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> Saxy.parse_string(__MODULE__, {nil, [], channel})
  end

  def parse(%File.Stream{} = stream, channel) when is_map(stream) do
    stream
    |> Stream.map(&Helper.fix_known_errors/1)
    |> Stream.filter(&(&1 != "\n"))
    |> Saxy.parse_stream(__MODULE__, {nil, [], channel})
  end

  def parse(_, _), do: {:error, "needs to be a File strng"}

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, airings, _}) do
    {:ok, airings |> Helper.sort_by_start_time()}
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {day, [%{text_key: _} | airings], channel}) do
    handle_event(:start_element, {key, attributes}, {day, airings, channel})
  end

  # Start of a day
  def handle_event(:start_element, {"day", attributes}, {_, airings, channel}) do
    attr = attributes |> Enum.into(%{})

    case attr |> Map.get("date") |> parse_date(channel) do
      {:ok, date} -> {:ok, {date, airings, channel}}
      _ -> {:ok, {nil, airings, channel}}
    end
  end

  # Start of a airing
  def handle_event(:start_element, {"program", _}, {date, airings, channel}) do
    {:ok, {date, [%{} | airings], channel}}
  end

  # Start of a start time
  def handle_event(:start_element, {"startTime", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "start_time"} | airings], channel}}
  end

  # Start of a live
  def handle_event(:start_element, {"live", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "live"} | airings], channel}}
  end

  # Start of a bline
  def handle_event(:start_element, {"bline", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "bline"} | airings], channel}}
  end

  # Start of a title
  def handle_event(:start_element, {"name", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "title"} | airings], channel}}
  end

  # Start of a org. title
  def handle_event(:start_element, {"orgName", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "original_title"} | airings], channel}}
  end

  # Start of a episode title
  def handle_event(:start_element, {"episodeTitle", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "subtitle"} | airings], channel}}
  end

  # Start of a widescreen
  def handle_event(:start_element, {"wideScreen", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "widescreen"} | airings], channel}}
  end

  # Start of a hd
  def handle_event(:start_element, {"highDefinition", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "hd"} | airings], channel}}
  end

  # Start of a program type
  def handle_event(:start_element, {"category", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "program_type"} | airings], channel}}
  end

  # PROD COuNTRY
  # Start of Production Year
  def handle_event(:start_element, {"productionYear", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "production_year"} | airings], channel}}
  end

  # Start of a genre
  def handle_event(:start_element, {"genre", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "genre"} | airings], channel}}
  end

  # Start of a episode description
  def handle_event(:start_element, {"synopsisThisEpisode", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "episode_description"} | airings], channel}}
  end

  # Start of a content description
  def handle_event(:start_element, {"synopsis", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "content_description"} | airings], channel}}
  end

  # Start of a season
  def handle_event(:start_element, {"season", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "season"} | airings], channel}}
  end

  # Start of a episode
  def handle_event(:start_element, {"episode", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "episode"} | airings], channel}}
  end

  # Start of a cast member
  def handle_event(:start_element, {"castMember", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "cast_member"} | airings], channel}}
  end

  # Start of a director
  def handle_event(:start_element, {"director", _}, {date, airings, channel}) do
    {:ok, {date, [%{text_key: "director"} | airings], channel}}
  end

  # Start of image
  def handle_event(
        :start_element,
        {"image", attrs},
        {date, airings, channel}
      ) do
    credits = attrs |> Enum.into(%{}) |> Map.get("credits")

    {:ok, {date, {%ImageManager.Image{type: "content", copyright: credits}, airings}, channel}}
  end

  def handle_event(
        :start_element,
        {"original", attrs},
        {date, {image, airings}, channel}
      ) do
    [airing | actual_airings] = airings
    src = attrs |> Enum.into(%{}) |> Map.get("src")

    images = [Map.put(image, :source, src) | Map.get(airing, :images, [])]

    {:ok, {date, [Map.put(airing, :images, images) | airings], channel}}
  end

  ###### NO MATCH HANDLERS

  # No match? Just return the state
  def handle_event(:start_element, {_name, _attributes}, state) do
    {:ok, state}
  end

  # No match just return state
  def handle_event(:end_element, _name, state) do
    {:ok, state}
  end

  ############# INCOMING VALUES

  # A start time
  def handle_event(:characters, _, {nil, [%{text_key: "start_time"} | _], _} = state) do
    {:ok, state}
  end

  def handle_event(:characters, chars, {date, [%{text_key: "start_time"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Map.put(:start_time, into_datetime(date, chars, channel))

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A tag if its live
  def handle_event(:characters, chars, {date, [%{text_key: "live"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      if chars |> Text.to_boolean() do
        airing
        |> Helper.merge_list(
          :qualifiers,
          "live"
        )
      else
        airing
      end

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # The airing title
  def handle_event(:characters, chars, {date, [%{text_key: "title"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Helper.merge_list(
        :titles,
        Text.string_to_map(
          chars |> Text.norm(),
          channel |> Helper.get_schedule_language(),
          "content"
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # The production year
  def handle_event(
        :characters,
        chars,
        {date, [%{text_key: "production_year"} | airings], channel}
      ) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Map.put(:production_date, Text.year_to_date(chars))

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # The airing title
  def handle_event(:characters, chars, {date, [%{text_key: "original_title"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Helper.merge_list(
        :titles,
        Text.string_to_map(
          chars |> Text.norm(),
          nil,
          "original"
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # The episode title
  def handle_event(:characters, chars, {date, [%{text_key: "subtitle"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Helper.merge_list(
        :subtitles,
        Text.string_to_map(
          chars |> Text.norm(),
          channel |> Helper.get_schedule_language(),
          "content"
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A tag if its WS
  def handle_event(:characters, chars, {date, [%{text_key: "widescreen"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      if chars |> Text.to_boolean() do
        airing
        |> Helper.merge_list(
          :qualifiers,
          "widescreen"
        )
      else
        airing
      end

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A tag if its HD
  def handle_event(:characters, chars, {date, [%{text_key: "hd"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      if chars |> Text.to_boolean() do
        airing
        |> Helper.merge_list(
          :qualifiers,
          "HD"
        )
      else
        airing
      end

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A program_type
  def handle_event(:characters, chars, {date, [%{text_key: "program_type"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> append_categories(
        Translation.translate_category(
          "Viasat_type",
          chars |> Text.norm() |> try_to_split(",")
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A genre
  def handle_event(:characters, chars, {date, [%{text_key: "genre"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> append_categories(
        Translation.translate_category(
          "Viasat_genre",
          chars |> Text.norm() |> try_to_split(",")
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A episode description
  def handle_event(
        :characters,
        chars,
        {date, [%{text_key: "episode_description"} | airings], channel}
      ) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Helper.merge_list(
        :descriptions,
        Text.string_to_map(
          chars |> Text.norm(),
          channel |> Helper.get_schedule_language(),
          "episode"
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A content description
  def handle_event(
        :characters,
        chars,
        {date, [%{text_key: "content_description"} | airings], channel}
      ) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Helper.merge_list(
        :descriptions,
        Text.string_to_map(
          chars |> Text.norm(),
          channel |> Helper.get_schedule_language(),
          "content"
        )
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A season number
  def handle_event(:characters, chars, {date, [%{text_key: "season"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Map.put(:season, chars |> Text.to_integer())

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # An episode number
  def handle_event(:characters, chars, {date, [%{text_key: "episode"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      airing
      |> Map.put(:episode, chars |> Text.to_integer())

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # An bline
  def handle_event(:characters, chars, {date, [%{text_key: "bline"} | airings], channel}) do
    [airing | actual_airings] = airings

    new_airing =
      if Regex.match?(~r/(?<production_year>\d{4}?)/i, chars) do
        matches =
          Regex.named_captures(
            ~r/(?<production_year>\d{4}?)/i,
            chars
          )

        airing
        |> Map.put(:production_date, Text.year_to_date(Map.get(matches, "production_year")))
      else
        airing
      end

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A cast member
  def handle_event(:characters, chars, {date, [%{text_key: "cast_member"} | airings], channel}) do
    [airing | actual_airings] = airings

    # Below is a regex to check if the text includes
    # See full cast & crew which for some reason they include in the export
    new_airing =
      if Regex.match?(~r/see full/i, chars) do
        airing
      else
        airing
        |> Helper.merge_list(
          :credits,
          %{
            type: "actor",
            person: chars |> Text.norm()
          }
        )
      end

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  # A director
  def handle_event(:characters, chars, {date, [%{text_key: "director"} | airings], channel}) do
    [airing | actual_airings] = airings

    maps =
      chars
      |> String.split(", ")
      |> Okay.map(fn person ->
        %{
          person: Text.norm(person),
          type: "director"
        }
      end)
      |> Okay.reject(&is_nil(&1.person))

    new_airing =
      airing
      |> Helper.merge_list(
        :credits,
        maps
      )

    {:ok, {date, [new_airing | actual_airings], channel}}
  end

  def handle_event(:characters, _chars, state), do: {:ok, state}

  # Turn a mix of naitve datetime and time into a utc dt
  defp into_datetime(date, time, _channel) do
    [hour, minute] = time |> String.split(":")

    date
    |> Timex.to_datetime()
    |> Timex.set(
      hour: hour |> String.to_integer(),
      minute: minute |> String.to_integer()
    )
  end

  # Parse a date string
  defp parse_date(nil, _), do: nil
  defp parse_date("", _), do: nil

  defp parse_date(string, channel) do
    lang = Map.get(channel || %{}, :schedule_languages, []) |> List.first()

    cond do
      lang == "lt" && Regex.match?(~r/(\d{4})\.(\d{2})\.(\d{2})/, string) ->
        Timex.parse(string, "{YYYY}.{0M}.{0D}")

      Regex.match?(~r/(\d{4})\.(\d{2})\.(\d{2})/, string) ->
        Timex.parse(string, "{YYYY}.{0D}.{0M}")

      Regex.match?(~r/(\d{2})\.(\d{2})\.(\d{4})/, string) ->
        Timex.parse(string, "{0D}.{0M}.{YYYY}")

      true ->
        DateTimeParser.parse_date(string)
    end
  end
end
