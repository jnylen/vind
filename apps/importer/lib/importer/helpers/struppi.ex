defmodule Importer.Helpers.Struppi do
  @moduledoc """
  A Struppi-file helper.
  """

  import SweetXml, except: [parse: 1, parse: 2]
  import Importer.Helpers.Xml
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  use Importer.Helpers.Translation

  require OK
  use OK.Pipe

  # TODO: Add descriptions for non VG Media licensed channels (I.E: VIMN channels)

  @doc """
  Parse an XML string in the Struppi format
  """
  def process(body, channel \\ nil, time_format \\ "{ISO:Extended}", opts \\ [])

  def process({:ok, body}, channel, time_format, opts),
    do: process(body, channel, time_format, opts)

  def process({:error, reason}, _, _, _), do: {:error, reason}

  def process(body, channel, time_format, opts) do
    OK.for do
      parsed_body <- process_body(body, channel, time_format, opts)

      airings =
        parsed_body
        |> Enum.sort(&(&1.start_time < &2.start_time))
        |> Enum.to_list()
    after
      airings
    end
  end

  # Return the data in wanted form
  defp process_body(body, channel, time_format, opts) do
    body
    |> parse(opts)
    ~>> xpath(
      ~x"//sendung"l,
      start_time: ~x".//termin/@start"S |> transform_by(&parse_datetime(&1, time_format)),
      end_time: ~x".//termin/@ende"S |> transform_by(&parse_datetime(&1, time_format)),
      content_title: ~x".//titel/@termintitel"S |> transform_by(&Text.norm/1),
      aliases: [
        ~x".//titel/alias"l,
        value: ~x"./@aliastitel"S |> transform_by(&Text.norm/1),
        type: ~x"./@titelart"S |> transform_by(&alias_type/1)
      ],
      episode_num: ~x".//infos/folge/@folgennummer"Io,
      season_num: ~x".//infos/folge/@staffel"Io,
      program_type: ~x".//infos/klassifizierung/@formatgruppe"So,
      genre: ~x".//infos/klassifizierung/@hauptgenre"So,
      production_year:
        ~x".//infos/produktion[@gueltigkeit='sendung']/produktionszeitraum/jahr/@von"Io,
      production_country:
        ~x".//infos/produktion[@gueltigkeit='sendung']/produktionsland[@laenderschema='kfz']/@laendername"lSo,
      audioformat: ~x".//infos/sonderzeichen/dolby/@version"So,
      videoformat: ~x".//infos/sonderzeichen/bildverhaeltnis/@verhaeltnis"So,
      is_hd: ~x".//infos/sonderzeichen/hd/@vorhanden"So |> Text.transform_to_boolean()
    )
    |> Enum.map(&process_item(&1, channel))
    |> Enum.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add qualifiers
  defp process_item(item, channel) do
    %{
      start_time: item[:start_time],
      end_time: item[:end_time],
      titles: parse_titles(channel, item[:content_title], item[:aliases]),
      subtitles: parse_subtitles(channel, item[:aliases]),
      episode: item[:episode_num],
      season: item[:season_num]
    }
    |> append_countries(
      Translation.translate_country(
        "Struppi",
        item[:production_country]
      )
    )
    |> append_categories(
      Translation.translate_category(
        "Struppi_category",
        try_to_split(item[:program_type], ",")
      )
    )
    |> append_categories(
      Translation.translate_category(
        "Struppi_genre",
        try_to_split(item[:genre], ",")
      )
    )
  end

  # Different types for titles
  defp parse_titles(channel, content_title, aliases) do
    title =
      Text.convert_string(
        content_title,
        List.first(channel.schedule_languages),
        "content"
      )

    alias_titles =
      aliases
      |> Enum.reject(&is_a?("title", &1.type))
      |> Enum.map(fn aitem ->
        Text.convert_string(
          aitem[:value],
          if aitem[:type] == "original_title" do
            nil
          else
            List.first(channel.schedule_languages)
          end,
          String.replace(aitem[:type], "original_title", "original")
        )
      end)

    (title ++ alias_titles)
    |> List.flatten()
  end

  # Different types for subtitles
  defp parse_subtitles(channel, aliases) do
    aliases
    |> Enum.reject(&is_a?("subtitle", &1.type))
    |> Enum.map(fn aitem ->
      Text.convert_string(
        aitem[:value],
        if aitem[:type] == "original_subtitle" do
          nil
        else
          List.first(channel.schedule_languages)
        end,
        String.replace(
          String.replace(aitem[:type], "original_subtitle", "original"),
          "content_subtitle",
          "content"
        )
      )
    end)
    |> List.flatten()
  end

  # Reject a string if isnt a type
  defp is_a?("title", string),
    do: !Enum.member?(["content", "original_title", "series"], string)

  defp is_a?("subtitle", string),
    do: !Enum.member?(["content_subtitle", "original_subtitle"], string)

  # translate struppi alias types to Vind.
  defp alias_type(string) do
    case string do
      "titel" -> "content"
      "originaltitel" -> "original_title"
      "reihentitel" -> "series"
      "untertitel" -> "content_subtitle"
      "originaluntertitel" -> "original_subtitle"
      _ -> nil
    end
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 20181214020000 +0100
  def parse_datetime(%DateTime{} = datetime, _) when is_map(datetime) do
    datetime
    |> Timex.Timezone.convert("UTC")
  end

  def parse_datetime(datetime_string, "{ISO:Extended}") do
    Timex.parse!(datetime_string, "{ISO:Extended}")
    |> Timex.Timezone.convert("UTC")
  end

  def parse_datetime(datetime_string, time_format) do
    datetime_string
    |> Timex.parse!(time_format, :strftime)
    |> Timex.to_datetime("Europe/Berlin")
    |> Timex.Timezone.convert("UTC")
  end
end
