defmodule Importer.Parser.CMore do
  @moduledoc """
  A parser for the old CMore XML files
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Sport, as: SportHelper
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
    |> Saxy.parse_stream(__MODULE__, {nil, {false, []}, channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> Saxy.parse_string(__MODULE__, {nil, {false, []}, channel})
  end

  def parse(_, _), do: {:error, "needs to be a File stream"}

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, {_, airings}, _}) do
    {:ok, airings |> Helper.sort_by_start_time()}
  end

  # Handle channel matching
  def handle_event(
        :start_element,
        {"Channel", [{"ChannelId", channel_id} | _]},
        {_, {_, airings}, channel}
      ) do
    if channel_id |> to_string() == channel |> Map.get(:grabber_info, "") |> to_string() do
      {:ok, {nil, {true, airings}, channel}}
    else
      {:ok, {nil, {false, airings}, channel}}
    end
  end

  def handle_event(:end_element, {"Channel", _}, {_, {_, airings}, channel}) do
    {:ok, {nil, {false, airings}, channel}}
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {val, airings, channel})
      when not is_nil(val) do
    handle_event(:start_element, {key, attributes}, {nil, airings, channel})
  end

  # Start of an airing
  def handle_event(
        :start_element,
        {"Schedule", attributes},
        {_, {true, airings}, channel}
      ) do
    attributes = attributes |> Enum.into(%{})

    airing = %{
      cmore_type: attributes |> Map.get("Type"),
      start_time: attributes |> Map.get("CalendarDate") |> parse_datetime()
    }

    {:ok, {nil, {true, [airing | airings]}, channel}}
  end

  def handle_event(:end_element, {"Schedule", _}, {_, airings, channel}) do
    {:ok, {nil, airings, channel}}
  end

  # Program
  def handle_event(
        :start_element,
        {"Program", attributes},
        {_, {true, [airing | airings]}, channel}
      ) do
    attributes = attributes |> Enum.into(%{})

    new_airing =
      airing
      |> parse_program(attributes, channel)

    {:ok, {nil, {true, [new_airing | airings]}, channel}}
  end

  def handle_event(:end_element, {"Program", _}, {_, airings, channel}) do
    {:ok, {nil, airings, channel}}
  end

  # Descriptions
  def handle_event(
        :start_element,
        {"Image", attributes},
        {_, {true, [airing | airings]}, channel}
      ) do
    attributes = attributes |> Enum.into(%{})

    url =
      if channel.library == "Web.MTV3" do
        "https://image-mtv-junecomet.azureedge.net/" <>
          Map.get(attributes, "Id") <> "/16x9_Max.jpg"
      else
        "https://img-cdn.b17g.net/" <> Map.get(attributes, "Id") <> "/originalsize.jpg"
      end

    new_airing =
      airing
      |> Helper.merge_list(
        :images,
        %ImageManager.Image{
          type: "content",
          source: url
        }
      )

    {:ok, {nil, {true, [new_airing | airings]}, channel}}
  end

  def handle_event(:end_element, {"Image", _}, {_, {true, _} = airings, channel}) do
    {:ok, {nil, airings, channel}}
  end

  # Descriptions
  def handle_event(:start_element, {"Long", _}, {_, {true, _} = airings, channel}) do
    {:ok, {"Long", airings, channel}}
  end

  def handle_event(:end_element, {"Long", _}, {_, {true, _} = airings, channel}) do
    {:ok, {nil, airings, channel}}
  end

  def handle_event(:characters, chars, {"Long", {true, [airing | airings]}, channel}) do
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

    {:ok, {nil, {true, [new_airing | airings]}, channel}}
  end

  # Catchalls
  def handle_event(:start_element, {_name, _attributes}, state), do: {:ok, state}
  def handle_event(:end_element, _name, state), do: {:ok, state}
  def handle_event(:characters, _chars, state), do: {:ok, state}

  # Parse program

  ## Sports
  defp parse_program(airing, %{"Category" => "Game"} = attributes, channel) do
    sports_genre =
      SportHelper.translate_type(
        "CMore_sport",
        Text.split(attributes |> Map.get("GenreKey") |> Text.norm(), "/")
      )

    league =
      SportHelper.map_league(
        SportHelper.translate_league(
          "cmore",
          sports_genre,
          attributes |> Map.get("SeriesTitle") |> Text.norm()
        )
      )

    teams =
      if is_nil(league) do
        []
      else
        String.split(
          attributes |> Map.get("EpisodeTitle") |> Text.norm() ||
            attributes |> Map.get("OriginalTitle") |> Text.norm(),
          " - "
        )
        |> Enum.map(fn team ->
          SportHelper.map_team(SportHelper.translate_team("cmore", sports_genre, team))
        end)
      end

    airing
    |> Map.put(:program_type, "sports_event")
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        attributes |> Map.get("Title") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "content"
      )
    )
    |> Map.put(:sport, %{
      event: league,
      teams: Enum.filter(teams, &(!is_nil(&1))),
      game: nil
    })
    |> append_categories(
      Translation.translate_category(
        "CMore_sport",
        Text.split(attributes |> Map.get("GenreKey") |> Text.norm(), "/")
      )
    )
    |> add_qualifier("type", airing |> Map.get(:cmore_type))
  end

  ## Event
  defp parse_program(airing, %{"Category" => "Event"} = attributes, channel) do
    sports_genre =
      SportHelper.translate_type(
        "CMore_event",
        Text.split(attributes |> Map.get("GenreKey") |> Text.norm(), "/")
      )

    league =
      SportHelper.map_league(
        SportHelper.translate_league(
          "cmore",
          sports_genre,
          attributes |> Map.get("SeriesTitle") |> Text.norm()
        )
      )

    airing
    |> Map.put(:program_type, if(is_nil(sports_genre), do: "sports", else: "sports_event"))
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        attributes |> Map.get("Title") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "content"
      )
    )
    |> Map.put(:sport, %{
      event: league,
      game: nil
    })
    |> append_categories(
      Translation.translate_category(
        "CMore_event",
        Text.split(attributes |> Map.get("GenreKey") |> Text.norm(), "/")
      )
    )
    |> add_qualifier("type", airing |> Map.get(:cmore_type))
  end

  ## Normal
  defp parse_program(airing, attributes, channel) do
    airing
    |> Map.put(
      :program_type,
      if(Map.get(attributes, "Category") == "Film", do: "movie", else: nil)
    )
    |> Map.put(:season, attributes |> Map.get("SeasonNumber") |> Text.to_integer())
    |> Map.put(:episode, attributes |> Map.get("EpisodeNumber") |> Text.to_integer())
    |> add_credits(parse_credits(attributes |> Map.get("Actors", ""), "actor"))
    |> add_credits(parse_credits(attributes |> Map.get("Directors", ""), "director"))
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        attributes |> Map.get("OriginalTitle") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "original"
      )
    )
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        attributes |> Map.get("Title") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "content"
      )
    )
    |> Helper.merge_list(
      :titles,
      Text.string_to_map(
        attributes |> Map.get("SeriesTitle") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "series"
      )
    )
    |> Helper.merge_list(
      :subtitles,
      Text.string_to_map(
        attributes |> Map.get("EpisodeTitle") |> Text.norm(),
        channel |> Helper.get_schedule_language(),
        "content"
      )
    )
    |> append_categories(
      Translation.translate_category(
        "CMore_genre",
        Text.split(attributes |> Map.get("GenreKey") |> Text.norm(), "/")
      )
    )
    |> add_qualifier("type", airing |> Map.get(:cmore_type))
    |> add_production_year(attributes |> Map.get("ProductionYear"))
  end

  defp add_production_year(airing, nil), do: airing

  defp add_production_year(airing, chars) do
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
  end

  # Add qualifier
  defp add_qualifier(airing, "type", "Live") do
    airing
    |> Helper.merge_list(:qualifiers, ["live"])
  end

  defp add_qualifier(airing, "type", _), do: airing

  defp add_qualifier(airing, text, true) do
    airing
    |> Helper.merge_list(:qualifiers, [text])
  end

  defp add_qualifier(airing, _, _), do: airing

  # Parse datetime
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

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(",")
    |> Enum.map(fn person ->
      %{
        person: Text.norm(person),
        type: type
      }
    end)
    |> Enum.reject(&is_nil(&1.person))
  end

  # Add credits
  defp add_credits(%{} = airing, list) when is_list(list) do
    airing
    |> Helper.merge_list(:credits, list)
  end
end
