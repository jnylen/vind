defmodule Importer.Parser.Struppi do
  @moduledoc """
  Parser for the Struppi DTD Format
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper

  @allowed_title_types %{
    "originaltitel" => "original",
    "reihentitel" => "series"
  }

  @allowed_subtitle_types %{
    "untertitel" => "content",
    "originaluntertitel" => "original"
  }

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
    airings
    |> Helper.sort_by_start_time()
    |> Enum.reject(fn airing ->
      airing.type |> String.downcase() == "loeschen"
    end)
    |> OK.wrap()
  end

  # If a new element starts, remove the text_key.
  def handle_event(:start_element, {key, attributes}, {[%{text_key: _} | airings], channel}) do
    handle_event(:start_element, {key, attributes}, {airings, channel})
  end

  # Start of an airing
  def handle_event(:start_element, {"sendung", _}, {airings, channel}) do
    {:ok, {[%{} | airings], channel}}
  end

  # Parse start and end datetimes
  def handle_event(:start_element, {"termin", attributes}, {[airing | airings], channel}) do
    # Get timestamps
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "termintyp" => type,
          "start" => start_dt,
          "ende" => _end_dt
        } ->
          airing
          |> Map.put(:type, type)
          |> Map.put(:start_time, start_dt |> parse_datetime())

        # |> Map.put(:end_time, end_dt |> parse_datetime())

        %{
          "vorhanden" => "true",
          "art" => "Live"
        } ->
          airing
          |> Helper.merge_list(
            :qualifiers,
            "live"
          )

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse content title
  def handle_event(:start_element, {"titel", attributes}, {[airing | airings], channel}) do
    # Put into map
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "termintitel" => value,
          "sprache" => language
        } ->
          airing
          |> Helper.merge_list(
            :titles,
            Text.string_to_map(
              value |> Text.norm(),
              language,
              "content"
            )
          )

        %{
          "termintitel" => value
        } ->
          airing
          |> Helper.merge_list(
            :titles,
            Text.string_to_map(
              value |> Text.norm(),
              channel |> Helper.get_schedule_language(),
              "content"
            )
          )

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse translations
  def handle_event(:start_element, {"alias", attributes}, {[airing | airings], channel}) do
    # Put into map
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "aliastitel" => value,
          "titelart" => type,
          "sprache" => language
        } ->
          cond do
            Map.has_key?(@allowed_title_types, type) ->
              airing
              |> Helper.merge_list(
                :titles,
                Text.string_to_map(
                  value |> Text.norm(),
                  language,
                  Map.get(@allowed_title_types, type)
                )
              )

            Map.has_key?(@allowed_subtitle_types, type) ->
              airing
              |> Helper.merge_list(
                :subtitles,
                Text.string_to_map(
                  value |> Text.norm(),
                  language,
                  Map.get(@allowed_subtitle_types, type)
                )
              )

            true ->
              airing
          end

        %{
          "aliastitel" => value,
          "titelart" => type
        } ->
          cond do
            Map.has_key?(@allowed_title_types, type) ->
              airing
              |> Helper.merge_list(
                :titles,
                Text.string_to_map(
                  value |> Text.norm(),
                  channel |> Helper.get_schedule_language(),
                  Map.get(@allowed_title_types, type)
                )
              )

            Map.has_key?(@allowed_subtitle_types, type) ->
              airing
              |> Helper.merge_list(
                :subtitles,
                Text.string_to_map(
                  value |> Text.norm(),
                  channel |> Helper.get_schedule_language(),
                  Map.get(@allowed_subtitle_types, type)
                )
              )

            true ->
              airing
          end

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse start and end datetimes
  def handle_event(:start_element, {"klassifizierung", attributes}, {[airing | airings], channel}) do
    # Get timestamps
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "formatgruppe" => program_type,
          "hauptgenre" => genre
        } ->
          airing
          |> append_categories(
            Translation.translate_category(
              "Struppi_category",
              try_to_split(program_type, ",")
            )
          )
          |> append_categories(
            Translation.translate_category(
              "Struppi_genre",
              try_to_split(genre, ",")
            )
          )

        %{
          "formatgruppe" => program_type
        } ->
          airing
          |> append_categories(
            Translation.translate_category(
              "Struppi_category",
              try_to_split(program_type, ",")
            )
          )

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse start and end datetimes
  def handle_event(:start_element, {"hd", attributes}, {[airing | airings], channel}) do
    # Get timestamps
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "vorhanden" => "true"
        } ->
          airing
          |> Helper.merge_list(:qualifiers, "HD")

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse start and end datetimes
  def handle_event(:start_element, {"dolby", attributes}, {[airing | airings], channel}) do
    # Get timestamps
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "version" => "Dolby Digital 5.1"
        } ->
          airing
          |> Helper.merge_list(:qualifiers, "DD 5.1")

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse production year
  def handle_event(:start_element, {"jahr", attributes}, {[airing | airings], channel}) do
    # Get timestamps
    attributes = attributes |> Enum.into(%{})

    current_date =
      Map.get(airing, :production_date, "3000-01-01")
      |> to_string()
      |> DateTimeParser.parse_date!()

    new_airing =
      if String.to_integer(Map.get(attributes, "von")) < current_date.year do
        airing
        |> Map.put(:production_date, Text.year_to_date(Map.get(attributes, "von")))
      else
        airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Parse folge data
  def handle_event(:start_element, {"folge", attributes}, {[airing | airings], channel}) do
    # Put into map
    new_airing =
      case attributes |> Enum.into(%{}) do
        %{
          "folgennummer" => episode_num,
          "staffel" => season_num
        } ->
          airing
          |> Map.put(:episode, episode_num |> parse_num())
          |> Map.put(:season, season_num |> parse_num())

        %{
          "folgennummer" => episode_num
        } ->
          airing
          |> Map.put(:episode, episode_num |> parse_num())

        _ ->
          airing
      end

    {:ok, {[new_airing | airings], channel}}
  end

  # Synopsis
  def handle_event(:start_element, {"text", attributes}, {airings, channel} = state) do
    attrs = attributes |> Enum.into(%{})

    # Put into map
    cond do
      Map.get(attrs, "textart") === "Kurztext" ->
        {:ok,
         {[
            %{value: nil, language: Map.get(attrs, "sprache"), text_key: "synopsis_content"}
            | airings
          ], channel}}

      Map.get(attrs, "textart") === "Beschreibung" ->
        {:ok,
         {[
            %{value: nil, language: Map.get(attrs, "sprache"), text_key: "synopsis_series"}
            | airings
          ], channel}}

      true ->
        {:ok, state}
    end
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
          "synopsis_content" ->
            airing
            |> Helper.merge_list(
              :descriptions,
              Text.string_to_map(
                chars |> Text.norm(),
                item |> Map.get(:language) || channel |> Helper.get_schedule_language(),
                "content"
              )
            )

          "synopsis_series" ->
            airing
            |> Helper.merge_list(
              :descriptions,
              Text.string_to_map(
                chars |> Text.norm(),
                item |> Map.get(:language) || channel |> Helper.get_schedule_language(),
                "series"
              )
            )

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
    case DateTimeParser.parse_datetime(string) do
      {:ok, datetime} ->
        datetime
        |> Timex.to_datetime("Europe/Berlin")
        |> Timex.Timezone.convert("UTC")

      _ ->
        nil
    end
  end

  defp parse_num(num) do
    num
    |> Text.to_integer()
    |> case do
      0 -> nil
      val -> val
    end
  end
end
