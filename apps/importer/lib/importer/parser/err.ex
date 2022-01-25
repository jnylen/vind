defmodule Importer.Parser.ERR do
  @moduledoc """
  A parser for the ERR XML format
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
  def handle_event(:start_element, {"PROGRAM", _}, {_, airings, channel}) do
    {:ok, {nil, [%{} | airings], channel}}
  end

  def handle_event(:end_element, "PROGRAM", {_, [airing | airings], channel}) do
    [hour, mins] = Map.get(airing, :start_time) |> String.split(":")

    {:ok, start_time} =
      NaiveDateTime.from_erl!(
        {Map.get(airing, "start_date") |> Date.to_erl(),
         {String.to_integer(hour), String.to_integer(mins), 0}}
      )
      |> DateTime.from_naive("Europe/Tallinn")

    new_airing =
      airing
      |> Map.delete("start_date")
      |> Map.put(:start_time, start_time)

    {:ok, {nil, [new_airing | airings], channel}}
  end

  #######

  # Start of a start time
  def handle_event(:start_element, {"TIME_FROM", _}, {_, airings, channel}) do
    {:ok, {"start_time", airings, channel}}
  end

  def handle_event(:characters, chars, {"start_time", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put(:start_time, chars)

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a end time
  def handle_event(:start_element, {"DATE", _}, {_, airings, channel}) do
    {:ok, {"start_date", airings, channel}}
  end

  def handle_event(:characters, chars, {"start_date", [airing | airings], channel}) do
    new_airing =
      airing
      |> Map.put("start_date", parse_date(chars))

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a title
  def handle_event(:start_element, {"TITLE_SHORT", _}, {_, airings, channel}) do
    {:ok, {"title", airings, channel}}
  end

  def handle_event(:characters, chars, {"title", [airing | airings], channel}) do
    new_airing =
      airing
      |> Helper.merge_list(
        :titles,
        Text.string_to_map(
          chars |> Text.norm() |> String.replace("*", ""),
          channel |> Helper.get_schedule_language(),
          "content"
        )
      )

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a "title" (aka with episode nums etc)
  def handle_event(:start_element, {"TITLE", _}, {_, airings, channel}) do
    {:ok, {"title_mixin", airings, channel}}
  end

  def handle_event(:characters, chars, {"title_mixin", [airing | airings], channel}) do
    new_airing =
      cond do
        Regex.match?(~r/(\d+)\, (\d+)\/(\d+)/iu, chars) ->
          %{"season" => season, "episode" => episode} =
            Regex.named_captures(
              ~r/(?<season>[0-9]+?)\, (?<episode>[0-9]+?)\/(?<of_episode>[0-9]+?)/iu,
              chars
            )

          airing
          |> Map.put(:season, season |> Text.to_integer())
          |> Map.put(:episode, episode |> Text.to_integer())

        Regex.match?(~r/\, (\d+)\/(\d+)/iu, chars) ->
          %{"episode" => episode} =
            Regex.named_captures(
              ~r/\, (?<episode>[0-9]+?)\/(?<of_episode>[0-9]+?)/iu,
              chars
            )

          airing
          |> Map.put(:episode, episode |> Text.to_integer())

        true ->
          airing
      end

    # Format of <genre> <short_title> <season>, <episode>/<season> <orgtitle etc>

    {:ok, {nil, [new_airing | airings], channel}}
  end

  # Start of a subtitle
  # def handle_event(:start_element, {"SUBTITLE", _}, {_, airings, channel}) do
  #   {:ok, {"subtitle", airings, channel}}
  # end

  # def handle_event(:characters, chars, {"subtitle", [airing | airings], channel}) do
  #   new_airing =
  #     airing
  #     |> Helper.merge_list(
  #       :subtitles,
  #       Text.string_to_map(
  #         chars |> Text.norm(),
  #         channel |> Helper.get_schedule_language(),
  #         "content"
  #       )
  #     )

  #   {:ok, {nil, [new_airing | airings], channel}}
  # end

  # Start of a orgtitle
  def handle_event(:start_element, {"ORIGTITLE", _}, {_, airings, channel}) do
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

  # Start of a org subtitle
  def handle_event(:start_element, {"DESCRIPTION", _}, {_, airings, channel}) do
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

  defp parse_date(string) do
    case DateTimeParser.parse_date(string) do
      {:ok, date} ->
        date

      _ ->
        nil
    end
  end
end
