defmodule Importer.Parser.GlobalListings.XML do
  @moduledoc """
  A parser for the GlobalListings XML format
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
  alias Importer.Parser.Helper

  def parse(incoming, channel \\ nil)

  def parse(nil, _), do: {:error, "incoming value is nil."}

  def parse({:ok, incoming}, channel), do: parse(incoming, channel)
  def parse({:error, reason}, _), do: {:error, reason}

  def parse(%File.Stream{} = stream, channel) when is_map(stream) do
    stream
    |> Stream.filter(&(&1 != "\n"))
    |> Stream.map(&Helper.fix_known_errors/1)
    |> Saxy.parse_stream(__MODULE__, {nil, [], channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> Saxy.parse_string(__MODULE__, {nil, [], channel})
  end

  def parse(_, _), do: {:error, "needs to be a File stream"}

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, airings, _}) do
    {:ok, airings |> Helper.sort_by_start_time()}
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {val, airings, channel})
      when not is_nil(val) do
    handle_event(:start_element, {key, attributes}, {nil, airings, channel})
  end

  # Start of an airing
  def handle_event(:start_element, {"BROADCAST", _}, {_, airings, channel}) do
    {:ok, {nil, [%{} | airings], channel}}
  end

  def handle_event(:end_element, {"BROADCAST", _}, {_, airings, channel}) do
    {:ok, {nil, airings, channel}}
  end

  #######

  # Start of a start time
  def handle_event(:start_element, {"BROADCAST_START_DATETIME", _}, {_, airings, channel}) do
    {:ok, {"start_time", airings, channel}}
  end

  def handle_event(:characters, chars, {"start_time", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put(:start_time, parse_datetime(chars))

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a end time
  def handle_event(:start_element, {"BROADCAST_END_TIME", _}, {_, airings, channel}) do
    {:ok, {"end_time", airings, channel}}
  end

  def handle_event(:characters, chars, {"end_time", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put(:end_time, parse_datetime(chars))

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a title
  def handle_event(:start_element, {"BROADCAST_TITLE", _}, {_, airings, channel}) do
    {:ok, {"title", airings, channel}}
  end

  def handle_event(:characters, chars, {"title", [airing | airings], channel}) do
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

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a subtitle
  def handle_event(:start_element, {"BROADCAST_SUBTITLE", _}, {_, airings, channel}) do
    {:ok, {"subtitle", airings, channel}}
  end

  def handle_event(:characters, chars, {"subtitle", [airing | airings], channel}) do
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

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a orgtitle
  def handle_event(:start_element, {"PROGRAMME_TITLE_ORIGINAL", _}, {_, airings, channel}) do
    {:ok, {"original_title", airings, channel}}
  end

  def handle_event(:characters, chars, {"original_title", [airing | airings], channel}) do
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

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a production year
  def handle_event(:start_element, {"PROGRAMME_YEAR", _}, {_, airings, channel}) do
    {:ok, {"production_year", airings, channel}}
  end

  def handle_event(:characters, chars, {"production_year", [airing | airings], channel}) do
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

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a org subtitle
  def handle_event(:start_element, {"PROGRAMME_SUBTITLE_ORIGINAL", _}, {_, airings, channel}) do
    {:ok, {"original_subtitle", airings, channel}}
  end

  def handle_event(:characters, chars, {"original_subtitle", [airing | airings], channel}) do
    new_airing =
      airing
      |> Helper.merge_list(
        :subtitles,
        Text.string_to_map(
          chars |> Text.norm(),
          nil,
          "original"
        )
      )

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a season
  def handle_event(:start_element, {"SERIES_NUMBER", _}, {_, airings, channel}) do
    {:ok, {"season", airings, channel}}
  end

  def handle_event(:characters, chars, {"season", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put(:season, chars |> Text.to_integer())

    {:ok, {nil, [new_airing | airings], channel}}
  rescue
    _ -> {:ok, {nil, [airing | airings], channel}}
  catch
    _ -> {:ok, {nil, [airing | airings], channel}}
  end

  # Start of a episode
  def handle_event(:start_element, {"EPISODE_NUMBER", _}, {_, airings, channel}) do
    {:ok, {"episode", airings, channel}}
  end

  def handle_event(:characters, chars, {"episode", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put(:episode, chars |> Text.to_integer())

    {:ok, {nil, [new_airing | airings], channel}}
  rescue
    _ -> {:ok, {nil, [airing | airings], channel}}
  catch
    _ -> {:ok, {nil, [airing | airings], channel}}
  end

  ## image
  def handle_event(
        :start_element,
        {"image_URL", attrs},
        {_, airings, channel}
      ) do
    {:ok, {"image_URL", airings, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {"image_URL", [airing | airings], channel}
      ) do
    new_airing =
      airing
      |> Helper.merge_list(
        :images,
        %ImageManager.Image{
          type: "content",
          source: chars
        }
      )

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a org subtitle
  def handle_event(:start_element, {"TEXT_TEXT", _}, {_, airings, channel}) do
    {:ok, {"text", airings, channel}}
  end

  def handle_event(:characters, chars, {"text", [airing | airings], channel}) do
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

    {:ok, {nil, [new_airing | airings], channel}}
  end

  #######

  def handle_event(:start_element, {_name, _attributes}, state) do
    {:ok, state}
  end

  def handle_event(:end_element, _name, state) do
    {:ok, state}
  end

  def handle_event(:characters, _chars, state), do: {:ok, state}

  ############

  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string, to_utc: true) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end
end
