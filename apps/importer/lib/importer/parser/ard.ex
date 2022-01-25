defmodule Importer.Parser.ARD do
  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper

  @moduledoc """
  A parser for the ARD sendungsdaten format.
  """

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
        {"SENDEPLATZ", _},
        {nil, _, airings, channel}
      ) do
    {:ok, {%{}, nil, airings, channel}}
  end

  ## Push to map
  def handle_event(:end_element, "SENDEPLATZ", {nil, _, airings, channel}),
    do: {:ok, {nil, nil, airings, channel}}

  def handle_event(:end_element, "SENDEPLATZ", {item, _, airings, channel}),
    do: {:ok, {nil, nil, [parse_airing(item) | airings], channel}}

  ######### DATETIMES

  # Start time
  def handle_event(:start_element, {"SENDESTART", _}, {item, _, airings, channel}),
    do: {:ok, {item, "start_time", airings, channel}}

  def handle_event(:characters, chars, {item, "start_time", airings, channel}) do
    new_item =
      item
      |> Map.put_new(:start_time, chars |> parse_datetime())

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "SENDESTART", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # End time
  def handle_event(:start_element, {"SENDESTOP", _}, {item, _, airings, channel}),
    do: {:ok, {item, "end_time", airings, channel}}

  def handle_event(:characters, chars, {item, "end_time", airings, channel}) do
    new_item =
      item
      |> Map.put_new(:end_time, chars |> parse_datetime())

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "SENDESTOP", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # Content title
  def handle_event(:start_element, {"SENDUNGSTITELTEXT", _}, {item, _, airings, channel}),
    do: {:ok, {item, "content_title", airings, channel}}

  def handle_event(:characters, chars, {item, "content_title", airings, channel}) do
    new_item =
      item
      |> Helper.merge_list(
        :titles,
        Text.string_to_map(
          chars |> Text.norm(),
          "de",
          "content"
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "SENDUNGSTITELTEXT", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # Content subtitle
  def handle_event(:start_element, {"NEBENTITELTEXT", _}, {item, _, airings, channel}),
    do: {:ok, {item, "content_subtitle", airings, channel}}

  def handle_event(:characters, chars, {item, "content_subtitle", airings, channel}) do
    new_item =
      item
      |> Helper.merge_list(
        :subtitles,
        Text.string_to_map(
          chars |> Text.norm(),
          "de",
          "content"
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "NEBENTITELTEXT", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # Production Year
  def handle_event(:start_element, {"PRODUKTIONSJAHREINTRAG", _}, {item, _, airings, channel}),
    do: {:ok, {item, "production_year", airings, channel}}

  def handle_event(:characters, chars, {item, "production_year", airings, channel}) do
    new_item =
      if Regex.match?(~r/(?<production_year>\d{4}?)/i, chars) do
        matches =
          Regex.named_captures(
            ~r/(?<production_year>\d{4}?)/i,
            chars
          )

        item
        |> Map.put(:production_date, Text.year_to_date(Map.get(matches, "production_year")))
      else
        item
      end

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "PRODUKTIONSJAHREINTRAG", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # Content description
  def handle_event(:start_element, {"KURZINHALTSTEXT", _}, {item, _, airings, channel}),
    do: {:ok, {item, "content_description", airings, channel}}

  def handle_event(:characters, chars, {item, "content_description", airings, channel}) do
    new_item =
      item
      |> Helper.merge_list(
        :descriptions,
        Text.string_to_map(
          chars |> Text.norm(),
          "de",
          "content"
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "KURZINHALTSTEXT", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # # Credits (a bit messy)
  # def handle_event(:start_element, {"KATEGORIE", attributes}, {item, _, airings, channel}) do
  #   attrs = attributes |> Enum.into(%{})

  #   {:ok,
  #    {item, {nil, "credit", %{type: Map.get(attrs, "typ"), person: nil, role: nil}}, airings,
  #     channel}}
  # end

  # def handle_event(:end_element, "KATEGORIE", {item, _, airings, channel}),
  #   do: {:ok, {item, nil, airings, channel}}

  # ## Credits - Person
  # def handle_event(
  #       :start_element,
  #       {"PERSONEINTRAG", _},
  #       {item, {_, "credit", map}, airings, channel}
  #     ),
  #     do: {:ok, {item, {"person", "credit", map}, airings, channel}}

  # ### Merge firstname and lastname into one
  # def handle_event(
  #       :end_element,
  #       "PERSONEINTRAG",
  #       {item, {"person", "credit", map}, airings, channel}
  #     ) do
  #   first_name = Map.get(map, "vorname")
  #   last_name = Map.get(map, "nachname")

  #   # If nil, dont do shit
  #   if is_nil(first_name) && is_nil(last_name) do
  #     {:ok, {item, {nil, "credit", map |> clean_up_credit_map()}, airings, channel}}
  #   else
  #     new_map =
  #       map
  #       |> Map.put(:person, parse_name(map))
  #       |> Map.delete("vorname")
  #       |> Map.delete("nachname")
  #       |> parse_credit()

  #     new_item =
  #       item
  #       |> Helper.merge_list(
  #         :credits,
  #         new_map
  #       )

  #     {:ok, {new_item, {nil, "credit", map |> clean_up_credit_map()}, airings, channel}}
  #   end
  # end

  # #### Parse first name
  # def handle_event(
  #       :start_element,
  #       {"VORNAME", _},
  #       {item, {"person", "credit", map}, airings, channel}
  #     ),
  #     do: {:ok, {item, {"first_name", "credit", map}, airings, channel}}

  # def handle_event(:characters, chars, {item, {"first_name", "credit", map}, airings, channel}) do
  #   new_map =
  #     map
  #     |> Map.put("vorname", chars |> Text.norm())

  #   {:ok, {item, {"person", "credit", new_map}, airings, channel}}
  # end

  # def handle_event(:end_element, "VORNAME", {item, {_, "credit", map}, airings, channel}),
  #   do: {:ok, {item, {"person", "credit", map}, airings, channel}}

  # #### Parse last name
  # def handle_event(
  #       :start_element,
  #       {"NACHNAME", _},
  #       {item, {"person", "credit", map}, airings, channel}
  #     ),
  #     do: {:ok, {item, {"last_name", "credit", map}, airings, channel}}

  # def handle_event(:characters, chars, {item, {"last_name", "credit", map}, airings, channel}) do
  #   new_map =
  #     map
  #     |> Map.put("nachname", chars |> Text.norm())

  #   {:ok, {item, {"person", "credit", new_map}, airings, channel}}
  # end

  # def handle_event(:end_element, "NACHNAME", {item, {_, "credit", map}, airings, channel}),
  #   do: {:ok, {item, {"person", "credit", map}, airings, channel}}

  # #### Parse role
  # def handle_event(
  #       :start_element,
  #       {"ALTERNATIVNAME", _},
  #       {item, {_, "credit", map}, airings, channel}
  #     ),
  #     do: {:ok, {item, {"role", "credit", map}, airings, channel}}

  # def handle_event(:characters, chars, {item, {"role", "credit", map}, airings, channel}) do
  #   new_map =
  #     map
  #     |> Map.put(:role, chars |> Text.norm())

  #   {:ok, {item, {"person", "credit", new_map}, airings, channel}}
  # end

  # def handle_event(:end_element, "ALTERNATIVNAME", {item, {_, "credit", map}, airings, channel}),
  #   do: {:ok, {item, {"person", "credit", map}, airings, channel}}

  # Genre
  def handle_event(
        :start_element,
        {"GENREEINTRAG", attributes},
        {item, _, airings, channel}
      ) do
    attrs = attributes |> Enum.into(%{})

    new_item =
      item
      |> append_categories(
        Translation.translate_category(
          "ARD",
          Map.get(attrs, "genrename") |> Text.norm()
        )
      )

    {:ok, {new_item, nil, airings, channel}}
  end

  def handle_event(:end_element, "GENREEINTRAG", {item, _, airings, channel}),
    do: {:ok, {item, nil, airings, channel}}

  # TODO: Parse prod. year
  # TODO: Parse prod. country
  # TODO: Parse video quality
  # TODO: Parse video colour

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

  ## parse an airing
  defp parse_airing(item), do: item

  # parse a credit person name
  # defp parse_name(map) when is_map(map) do
  #   [Map.get(map, "vorname"), Map.get(map, "nachname")]
  #   |> Enum.join(" ")
  #   |> String.trim()
  # end

  # # parse credits
  # defp parse_credit(%{type: "Darsteller", person: person} = credit) when not is_nil(person) do
  #   credit
  #   |> Map.put(:type, "actor")
  # end

  # defp parse_credit(%{type: "Regie", person: person} = credit) when not is_nil(person) do
  #   credit
  #   |> Map.put(:type, "director")
  #   |> Map.delete(:role)
  # end

  # defp parse_credit(_), do: nil

  # defp clean_up_credit_map(map) do
  #   map
  #   |> IO.inspect()
  #   |> Map.delete("vorname")
  #   |> Map.delete("nachname")
  #   |> Map.put(:person, nil)
  #   |> Map.put(:role, nil)
  # end

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
end
