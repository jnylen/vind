defmodule Importer.Parser.Xmltv do
  @moduledoc """
  Parser for XMLTV DTD standard
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
    |> Saxy.parse_stream(__MODULE__, {[], channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> Saxy.parse_string(__MODULE__, {[], channel})
  end

  def parse(_, _), do: {:error, "needs to be a File stream"}

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {airings, _}) do
    {:ok, airings |> Enum.filter(&Map.has_key?(&1, :start_time)) |> Helper.sort_by_start_time()}
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {[%{text_key: _} | airings], channel}) do
    handle_event(:start_element, {key, attributes}, {airings, channel})
  end

  # Start of an airing
  def handle_event(:start_element, {"programme", attributes}, {airings, channel}) do
    airing =
      case attributes |> Enum.into(%{}) do
        %{
          "air_start_time" => start_dt,
          "air_end_time" => end_dt
        } ->
          %{}
          |> Map.put(:start_time, start_dt |> parse_datetime())
          |> Map.put(:end_time, end_dt |> parse_datetime())

        %{
          "air_time_start" => start_dt,
          "air_time_end" => end_dt
        } ->
          %{}
          |> Map.put(:start_time, start_dt |> parse_datetime())
          |> Map.put(:end_time, end_dt |> parse_datetime())

        %{
          "start" => start_dt,
          "stop" => end_dt
        } ->
          %{}
          |> Map.put(:start_time, start_dt |> parse_datetime())
          |> Map.put(:end_time, end_dt |> parse_datetime())

        %{
          "start" => start_dt
        } ->
          %{}
          |> Map.put(:start_time, start_dt |> parse_datetime())

        _ ->
          %{}
      end

    {:ok, {[airing | airings], channel}}
  end

  # Parse content title
  def handle_event(:start_element, {"title", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "title",
      language: Map.get(attrs, "lang"),
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse content subtitle
  def handle_event(:start_element, {"sub-title", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "subtitle",
      language: Map.get(attrs, "lang"),
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse desc
  def handle_event(:start_element, {"desc_short", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "description",
      language: Map.get(attrs, "lang"),
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse desc
  def handle_event(:start_element, {"desc", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "description",
      language: Map.get(attrs, "lang"),
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse category
  def handle_event(:start_element, {"category", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "category",
      language: Map.get(attrs, "lang"),
      value: nil
    }

    # MTV3 sends in a virtual product id as a category too
    cond do
      Map.get(attrs, "lang") == "vp" ->
        {:ok, {airings, channel}}

      true ->
        {:ok, {[new_airing | airings], channel}}
    end
  end

  # Parse director
  def handle_event(:start_element, {"director", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "director",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse actor
  def handle_event(:start_element, {"actor", attributes}, {airings, channel}) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    new_airing = %{
      text_key: "actor",
      role: Map.get(attrs, "role"),
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse presenter
  def handle_event(:start_element, {"presenter", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "presenter",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse start
  def handle_event(:start_element, {"start", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "start",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse stop
  def handle_event(:start_element, {"stop", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "stop",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse season-num
  def handle_event(:start_element, {"season-num", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "season-num",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse episode-num
  def handle_event(:start_element, {"episode-num", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "episode-num",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse episode-num
  def handle_event(:start_element, {"episode-num", [{"system", "xmltv_ns"}]}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "xmltv_ns",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse repeat
  def handle_event(:start_element, {"repeat", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "repeat",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse live
  def handle_event(:start_element, {"live", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "live",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse production_year
  def handle_event(:start_element, {"production_year", _}, {airings, channel}) do
    # Put into map
    new_airing = %{
      text_key: "production_year",
      value: nil
    }

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse icon
  def handle_event(:start_element, {"icon", attributes}, {[airing | airings], channel}) do
    attributes = attributes |> Enum.into(%{})

    new_airing =
      airing
      |> Helper.merge_list(
        :images,
        %ImageManager.Image{
          type: "content",
          source: Map.get(attributes, "src")
        }
      )

    {:ok, {[new_airing | airings], channel}}
  end

  def handle_event(:start_element, {_name, _attributes}, state) do
    {:ok, state}
  end

  def handle_event(:end_element, _name, state) do
    {:ok, state}
  end

  def handle_event(:characters, chars, {[item | airings], channel} = state) do
    # Is a text to parse?
    if item |> Map.has_key?(:text_key) do
      [airing | actual_airings] = airings

      new_airing =
        case item |> Map.get(:text_key) do
          "title" ->
            airing
            |> Helper.merge_list(
              :titles,
              Text.string_to_map(
                chars |> Text.norm(),
                item |> Map.get(:language) || channel |> Helper.get_schedule_language(),
                "content"
              )
            )

          "subtitle" ->
            airing
            |> Helper.merge_list(
              :subtitles,
              Text.string_to_map(
                chars |> Text.norm(),
                item |> Map.get(:language) || channel |> Helper.get_schedule_language(),
                "content"
              )
            )

          "description" ->
            airing
            |> Helper.merge_list(
              :descriptions,
              Text.string_to_map(
                chars |> Text.norm(),
                item |> Map.get(:language) || channel |> Helper.get_schedule_language(),
                "content"
              )
            )

          "category" ->
            airing
            |> append_categories(
              Translation.translate_category(
                "xmltv",
                chars |> Text.norm()
              )
            )

          "director" ->
            airing
            |> Helper.merge_list(
              :credits,
              %{
                type: "director",
                person: chars |> Text.norm()
              }
            )

          "actor" ->
            airing
            |> Helper.merge_list(
              :credits,
              %{
                type: "actor",
                person: chars |> Text.norm(),
                role: Map.get(item, :role)
              }
            )

          "presenter" ->
            airing
            |> Helper.merge_list(
              :credits,
              %{
                type: "presenter",
                person: chars |> Text.norm()
              }
            )

          "xmltv_ns" ->
            parsed_ep = chars |> parse_xmltv_ns()

            airing
            |> Map.put(:season, parsed_ep.season)
            |> Map.put(:episode, parsed_ep.episode)
            |> Map.put(:of_episode, parsed_ep.of_episode)

          "season-num" ->
            airing
            |> Map.put(:season, chars |> Helper.grab_int_from_text() |> Text.to_integer())

          "episode-num" ->
            airing
            |> Map.put(:episode, chars |> Helper.grab_int_from_text() |> Text.to_integer())

          "live" ->
            if chars |> Text.to_boolean() do
              airing
              |> Helper.merge_list(
                :qualifiers,
                "live"
              )
            else
              airing
            end

          "repeat" ->
            if chars |> Text.to_boolean() do
              airing
              |> Helper.merge_list(
                :qualifiers,
                "rerun"
              )
            else
              airing
            end

          "start" ->
            airing
            |> Map.put(:start_time, chars |> parse_datetime())

          "stop" ->
            airing
            |> Map.put(:end_time, chars |> parse_datetime())

          "production_year" ->
            airing
            |> Map.put(:production_date, Text.year_to_date(chars))

          _ ->
            airing
        end

      {:ok, {[new_airing | actual_airings], channel}}
    else
      {:ok, state}
    end
  end

  def handle_event(:characters, _chars, state), do: {:ok, state}

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string, to_utc: true) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

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
