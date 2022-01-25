defmodule Exporter.PremiumXmltv do
  use Exporter.Base
  alias Exporter.Helpers.Translations, as: TransHelper
  alias XMLTV.Channel
  alias XMLTV.Programme

  @moduledoc """
  Exports Premium XMLTV Files
  """

  @doc """
  The amount of days this export can do.

  Default is specified in `Exporter.Base`.
  """
  def days, do: 22

  @doc """
  Exports airings from a batch to a XMLTV-standard file.
  """
  def export(airings, channel) do
    airings
    |> to_struct(channel)
    |> sort_by_start_time()
    |> XMLTV.as_string(%{
      generator_name: "Vind",
      generator_url: "https://xmltv.se"
    })
    |> OK.wrap()
  end

  def export_channels(channels) do
    channels
    |> to_channel_structs()
    |> XMLTV.as_string(%{
      base_url: "http://xmltv.xmltv.se/",
      generator_name: "Vind",
      generator_url: "https://xmltv.se"
    })
    |> OK.wrap()
  end

  defp to_channel_structs([]), do: []

  defp to_channel_structs([channel | channels]) do
    [
      %Channel{
        id: new_xmltv_id?(channel),
        name: channel.display_names
      }
      | channels |> to_channel_structs() |> List.flatten()
    ]
    |> Enum.reverse()
  end

  defp to_struct([], _), do: []

  defp to_struct([airing | airings], channel) do
    [
      %Programme{
        start: airing.start_time,
        stop: airing.end_time,
        channel: new_xmltv_id?(channel),
        title: airing.titles |> TransHelper.sort() |> process_translations() |> Enum.reverse(),
        subtitle:
          airing.subtitles |> TransHelper.sort() |> process_translations() |> Enum.reverse(),
        desc: airing.descriptions |> sort_longest() |> process_translations() |> Enum.reverse(),
        credits: airing.credits,
        season: airing.season,
        episode: airing.episode,
        of_episodes: airing.of_episode,
        country: airing.production_countries,
        category: as_categories(airing, channel),
        new: Enum.member?(airing.qualifiers, "live"),
        previously_shown: Enum.member?(airing.qualifiers, "rerun")
      }
      | to_struct(airings, channel) |> List.flatten()
    ]
    |> Enum.reverse()
  end

  defp as_categories(airing, channel) do
    if is_nil(airing.program_type) do
      [channel.default_prog_type |> parse_default_prog_type]
    else
      [airing.program_type |> parse_program_type]
    end
    |> Enum.concat(airing.category || [])
    |> Enum.reject(&is_nil/1)
  end

  defp parse_default_prog_type(""), do: nil

  defp parse_default_prog_type(type) do
    case type do
      "movie" -> "movie"
      "series" -> "series"
      "sports" -> "sports"
      "sports_event" -> "sports"
      _ -> nil
    end
  end

  # TODO
  # Convert program_type
  defp parse_program_type(nil) do
    # IF NIL IT SHOULD DEFAULT TO THE CHANNELS DEFAULT CAT
    "series"
  end

  defp parse_program_type(type) do
    case type do
      "movie" -> "movie"
      "series" -> "series"
      "sports" -> "sports"
      "sports_event" -> "sports"
      _ -> "tvshow"
    end
  end

  defp sort_longest(list) when is_list(list) do
    list
    |> Enum.sort(&(String.length(&1.value) > String.length(&2.value)))
  end

  defp process_translations([]), do: []

  defp process_translations([item | list]) do
    if is_nil(Map.get(item, :value) |> Exporter.escape_binary()) do
      process_translations(list)
    else
      [
        item
        |> Map.put(:value, Map.get(item, :value) |> Exporter.escape_binary())
        | process_translations(list)
      ]
    end
  end

  def sort_by_start_time(items) do
    items
    |> Enum.reject(&is_nil(&1.start))
    |> Enum.sort_by(fn a ->
      {a.start.year, a.start.month, a.start.day, a.start.hour, a.start.minute}
    end)
  end

  defp new_xmltv_id?(channel) do
    channel.new_xmltv_id || channel.xmltv_id
  end
end
