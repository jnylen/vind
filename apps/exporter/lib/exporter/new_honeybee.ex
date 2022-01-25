defmodule Exporter.NewHoneybee do
  use Exporter.Base

  alias Exporter.Helpers.Translations, as: TransHelper

  @moduledoc """
  Basically just the old Honeybee JSON format.
  """

  @doc """
  The amount of days this export can do.

  Default is specified in `Exporter.Base`.
  """
  def days, do: 22

  @doc """
  Exports a file of airings in a JSON file.
  """
  def export(airings, channel) do
    %{
      "jsontv" => %{
        "programme" =>
          airings
          |> add_airing(channel)
          |> List.flatten()
          |> Enum.reject(&is_nil(Map.get(&1, "stop")))
      }
    }
    |> Jsonrs.encode!()
    |> OK.wrap()
  end

  def export_channels(channels) do
    %{
      "jsontv" => %{
        "channels" => channels |> add_channel() |> List.flatten()
      }
    }
    |> Jsonrs.encode!()
    |> OK.wrap()
  end

  defp add_airing(nil, _channel), do: []
  defp add_airing([], _channel), do: []

  defp add_airing([airing | airings], channel) do
    [
      %{
        "channel" => channel.xmltv_id,
        "start" => airing.start_time |> format_datetime(),
        "stop" => airing.end_time |> format_datetime(),
        "title" => airing.titles |> cleanup_trans() |> Enum.uniq() |> TransHelper.sort(),
        "desc" => airing.descriptions |> cleanup_trans() |> Enum.uniq() |> TransHelper.sort(),
        "subTitle" => airing.subtitles |> cleanup_trans() |> Enum.uniq() |> TransHelper.sort(),
        "program_type" => airing.program_type || channel.default_prog_type,
        "genres" => airing.category,
        "live" => Enum.member?(Map.get(airing, :qualifiers, []), "live"),
        "new" => tag_as_new?(airing),
        "production_date" => airing.production_date,
        "external" => %{
          "images" => nil
        },
        "image" => %{
          "fanart" => nil,
          "poster" => nil
        },
        "extra" => %{
          "qualifiers" => airing.qualifiers
        },
        "episode" => %{
          "season" => airing.season,
          "episode" => airing.episode,
          "of" => airing.of_episode
        },
        "credits" => airing.credits,
        "images" => image_files(airing.image_files)
      }
      | add_airing(airings, channel)
    ]
  end

  defp add_channel(nil), do: []
  defp add_channel([]), do: []

  defp add_channel([channel | channels]) do
    [
      %{
        # "icon" => "",
        "name" => channel.display_names |> get_one("value"),
        "language" => channel.schedule_languages |> List.first(),
        "defaults" => %{
          "category" => channel.default_category,
          "type" => channel.default_prog_type
        },
        "groups" => channel.channel_groups,
        "url" => nil,
        "xmltvid" => channel.xmltv_id
      }
      | add_channel(channels)
    ]
  end

  # Tag as new?
  defp tag_as_new?(airing) do
    cond do
      Enum.member?(Map.get(airing, :qualifiers, []), "premiere") -> true
      Enum.member?(Map.get(airing, :qualifiers, []), "new") -> true
      Enum.member?(Map.get(airing, :qualifiers, []), "rerun") -> false
      true -> nil
    end
  end

  # Format datetime into correct xmltv format
  defp format_datetime(nil), do: nil

  defp format_datetime(datetime) do
    datetime
    |> Timex.format!("{ISO:Extended:Z}")
  end

  defp get_one(list, "value") when is_list(list) do
    list
    |> List.pop_at(0)
    |> case do
      {nil, _} -> nil
      {map, _} -> map.value |> Exporter.escape_binary()
    end
  end

  defp get_one(list, "lang") when is_list(list) do
    list
    |> List.pop_at(0)
    |> case do
      {nil, _} -> nil
      {map, _} -> map.language
    end
  end

  defp cleanup_trans(list) when is_list(list), do: list |> Enum.map(&cleanup_trans/1)
  defp cleanup_trans(map), do: map |> Map.from_struct() |> Map.delete(:id)

  defp image_files([]), do: []

  defp image_files([%{file_name: file_name} = image | images]) when not is_nil(file_name) do
    [
      %{
        url: ImageManager.url_for(image),
        size: ImageManager.calculate_size(image),
        language: image.language,
        copyright: image.copyright,
        author: image.author
      }
      | image_files(images)
    ]
  end

  defp image_files([_image | images]), do: image_files(images)
end
