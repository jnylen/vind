defmodule Importer.Parser.TVAnytime do
  @moduledoc """
  A parser for the TVAnytime format
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.Helper

  def parse(incoming, channel \\ %{})

  def parse(nil, _), do: {:error, "incoming value is nil."}

  def parse({:ok, incoming}, channel), do: parse(incoming, channel)
  def parse({:error, reason}, _), do: {:error, reason}

  def parse(%File.Stream{} = stream, channel) when is_map(stream) do
    stream
    |> Stream.filter(&(&1 != "\n"))
    |> Stream.map(&Helper.fix_known_errors/1)
    |> Stream.map(fn text ->
      text
      |> String.replace("tva:", "")
      |> String.replace("mpeg7:", "")
      |> String.replace("ns2:", "")
    end)
    |> Saxy.parse_stream(__MODULE__, {nil, nil, {%{}, %{}, []}, channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> String.replace("tva:", "")
    |> String.replace("mpeg7:", "")
    |> String.replace("ns2:", "")
    |> Saxy.parse_string(__MODULE__, {nil, nil, {%{}, %{}, []}, channel})
  end

  def parse(_, _), do: {:error, "needs to be a File stream"}

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, _, {_, _, airings}, _}) do
    {:ok, airings |> Enum.reject(&is_nil/1) |> Helper.sort_by_start_time()}
  end

  # If a new element starts, remove the text_key.
  def handle_event(
        :start_element,
        {key, attributes},
        {item, %{text_key: _}, {content, materials, airings}, channel}
      ) do
    handle_event(
      :start_element,
      {key, attributes},
      {item, nil, {content, materials, airings}, channel}
    )
  end

  ####### contents
  def handle_event(
        :start_element,
        {"GroupInformation", attrs},
        {nil, _, {content, materials, airings}, channel}
      ) do
    map = %{
      "type" => "GroupInformation",
      "group_id" => Map.get(Enum.into(attrs, %{}), "groupId")
    }

    {:ok, {map, nil, {content, materials, airings}, channel}}
  end

  ######### member_of
  def handle_event(
        :start_element,
        {"MemberOf", attrs},
        {%{
           "type" => "GroupInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    new_item =
      item
      |> Helper.merge_list(
        "member_of",
        %{
          "crid" => Map.get(attrs, "crid"),
          "index" => Map.get(attrs, "index", "0") |> Text.to_integer()
        }
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ######### member_of
  def handle_event(
        :start_element,
        {"GroupType", attrs},
        {%{
           "type" => "GroupInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    {:ok,
     {Map.put_new(item, "group_type", Map.get(attrs, "value")), nil,
      {content, materials, airings}, channel}}
  end

  ## Push to map
  def handle_event(
        :end_element,
        "GroupInformation",
        {%{
           "type" => "GroupInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {nil, nil, {content, materials |> Map.put_new(Map.get(item, "group_id"), item), airings},
      channel}}
  end

  ## creditList
  def handle_event(
        :start_element,
        {"CreditsList", _},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"CreditsItem", {nil, %{}}, []}, {content, materials, airings}, channel}}
  end

  # START CREDIT

  ## Credit (to fetch Role for TV2 NO)
  def handle_event(
        :start_element,
        {"CreditsItem", attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    {:ok,
     {item,
      {"CreditsItem", {"CreditsItem", Map.put_new(map, "type", Map.get(attrs, "role"))}, items},
      {content, materials, airings}, channel}}
  end

  ## SeasonNumber (invalid TVA tag)

  def handle_event(
        :start_element,
        {"SeasonNumber", _},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "SeasonNumber", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, "SeasonNumber", {content, materials, airings}, channel}
      ) do
    {:ok,
     {Map.put_new(item, "season", Text.to_integer(chars)), nil, {content, materials, airings},
      channel}}
  end

  ## EpisodeNumber (invalid TVA tag)

  def handle_event(
        :start_element,
        {"EpisodeNumber", _},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "EpisodeNumber", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, "EpisodeNumber", {content, materials, airings}, channel}
      ) do
    {:ok,
     {Map.put_new(item, "episode", Text.to_integer(chars)), nil, {content, materials, airings},
      channel}}
  end

  ## First Name

  def handle_event(
        :start_element,
        {"GivenName", _},
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"CreditsItem", {"GivenName", map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"GivenName", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok,
     {item,
      {"CreditsItem", {"GivenName", map |> Map.put("first_name", chars |> Text.norm())}, items},
      {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "GivenName",
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"GivenName", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok, {item, {"CreditsItem", {nil, map}, items}, {content, materials, airings}, channel}}
  end

  ## Last name

  def handle_event(
        :start_element,
        {"FamilyName", _},
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"CreditsItem", {"FamilyName", map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"FamilyName", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok,
     {item,
      {"CreditsItem", {"FamilyName", map |> Map.put("last_name", chars |> Text.norm())}, items},
      {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "FamilyName",
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"FamilyName", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok, {item, {"CreditsItem", {nil, map}, items}, {content, materials, airings}, channel}}
  end

  ## ROLE

  def handle_event(
        :start_element,
        {"PresentationRole", _},
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"CreditsItem", {"PresentationRole", map}, items}, {content, materials, airings},
      channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"PresentationRole", map}, items},
         {content, materials, airings}, channel}
      ) do
    {:ok,
     {item,
      {"CreditsItem", {"PresentationRole", map |> Map.put("type", chars |> Text.norm())}, items},
      {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "PresentationRole",
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {"PresentationRole", map}, items},
         {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"CreditsItem", {nil, map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "CreditsItem",
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"CreditsItem", {nil, %{}}, [map | items]}, {content, materials, airings}, channel}}
  end

  # END CREDIT

  def handle_event(
        :end_element,
        "CreditsList",
        {%{
           "type" => "ProgramInformation"
         } = item, {"CreditsItem", _, credits}, {content, materials, airings}, channel}
      ) do
    {:ok, {item |> Map.put("credits", credits), nil, {content, materials, airings}, channel}}
  end

  ####### materials
  def handle_event(
        :start_element,
        {"ProgramInformation", attrs},
        {nil, _, {content, materials, airings}, channel}
      ) do
    map = %{
      "type" => "ProgramInformation",
      "program_id" => Map.get(Enum.into(attrs, %{}), "programId") |> parse_program_id()
    }

    {:ok, {map, nil, {content, materials, airings}, channel}}
  end

  ## Push to map
  def handle_event(
        :end_element,
        "ProgramInformation",
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {nil, nil,
      {content |> Map.put_new(Map.get(item, "program_id") |> parse_program_id(), item), materials,
       airings}, channel}}
  end

  ## Repeat
  def handle_event(
        :start_element,
        {"CaptionLanguage", _attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "qualifiers",
        "CC"
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ######### title
  def handle_event(
        :start_element,
        {"Title", attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"Title", Enum.into(attrs, %{})}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, {"Title", attrs}, {content, materials, airings}, channel}
      ) do
    title_type =
      case parse_text_type(Map.get(attrs, "type")) do
        "episode" -> "subtitles"
        _ -> "titles"
      end

    new_item =
      item
      |> Helper.merge_list(
        title_type,
        Text.string_to_map(
          chars |> Text.norm(),
          Map.get(attrs, "xml:lang") |> parse_text_language(),
          attrs
          |> Map.get("type")
          |> parse_text_type()
          |> String.replace("episode", "content")
        )
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  # START RelatedMaterial

  def handle_event(
        :start_element,
        {"RelatedMaterial", _},
        {%{
           "type" => type
         } = item, _, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    {:ok, {item, {"RelatedMaterial", %{}}, {content, materials, airings}, channel}}
  end

  ## HowRelated

  def handle_event(
        :start_element,
        {"HowRelated", attrs},
        {%{
           "type" => type
         } = item, {"RelatedMaterial", map}, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    attrs = attrs |> Enum.into(%{})

    {:ok,
     {item, {"RelatedMaterial", Map.put(map, "type", Map.get(attrs, "href"))},
      {content, materials, airings}, channel}}
  end

  # Image URL

  def handle_event(
        :start_element,
        {"MediaUri", _attrs},
        {%{
           "type" => type
         } = item, {"RelatedMaterial", map}, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    {:ok, {item, {"RelatedMaterial", {"MediaUri", map}}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => type
         } = item, {"RelatedMaterial", {"MediaUri", map}}, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    {:ok,
     {item, {"RelatedMaterial", map |> Map.put("source", chars)}, {content, materials, airings},
      channel}}
  end

  # Promo Text

  def handle_event(
        :start_element,
        {"PromotionalText", _attrs},
        {%{
           "type" => type
         } = item, {"RelatedMaterial", map}, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    {:ok,
     {item, {"RelatedMaterial", {"PromotionalText", map}}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => type
         } = item, {"RelatedMaterial", {"PromotionalText", map}}, {content, materials, airings},
         channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    new_map =
      map
      |> Helper.merge_list(
        "copyrights",
        chars
      )

    {:ok, {item, {"RelatedMaterial", new_map}, {content, materials, airings}, channel}}
  end

  # END RELATED MATERIAL

  def handle_event(
        :end_element,
        "RelatedMaterial",
        {%{
           "type" => type
         } = item, {"RelatedMaterial", map}, {content, materials, airings}, channel}
      )
      when type in ["GroupInformation", "ProgramInformation"] do
    new_item =
      item
      |> Helper.merge_list(
        "material",
        map
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ######### description
  def handle_event(
        :start_element,
        {"Synopsis", attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"Synopsis", Enum.into(attrs, %{})}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ProgramInformation"
         } = item, {"Synopsis", attrs}, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "descriptions",
        Text.string_to_map(
          chars |> Text.norm(),
          Map.get(attrs, "xml:lang") |> parse_text_language(),
          parse_text_type(Map.get(attrs, "length"))
        )
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ######### aspectratio
  def handle_event(
        :start_element,
        {"AspectRatio", _attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "AspectRatio", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        "16:9",
        {%{
           "type" => "ProgramInformation"
         } = item, "AspectRatio", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "qualifiers",
        "widescreen"
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "AspectRatio",
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ######### Handle genre

  def handle_event(
        :start_element,
        {"Genre", attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs
    |> Enum.into(%{})
    |> Map.get("href", "")
    |> clean_up_href()
    |> String.split(":")
    |> case do
      [genre_type, genre_year, genre_code] ->
        new_item =
          item
          |> Helper.merge_list(
            "genres",
            %{
              "year" => genre_year,
              "type" => genre_type,
              "code" => genre_code
            }
          )

        {:ok, {new_item, nil, {content, materials, airings}, channel}}

      _ ->
        {:ok, {item, nil, {content, materials, airings}, channel}}
    end
  end

  ######### episode_of
  def handle_event(
        :start_element,
        {"EpisodeOf", attrs},
        {%{
           "type" => "ProgramInformation"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    new_item =
      item
      |> Map.put_new("episode", Map.get(attrs, "index") |> Text.to_integer())
      |> Map.put_new("episode_crid", Map.get(attrs, "crid"))

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ####### events
  def handle_event(
        :start_element,
        {"ScheduleEvent", _},
        {nil, _, {content, materials, airings}, channel}
      ) do
    map = %{
      "type" => "ScheduleEvent"
    }

    {:ok, {map, nil, {content, materials, airings}, channel}}
  end

  ## Program ID
  def handle_event(
        :start_element,
        {"Program", attrs},
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("program_id", Map.get(Enum.into(attrs, %{}), "crid") |> parse_program_id())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ## start_time
  def handle_event(
        :start_element,
        {"PublishedStartTime", _},
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "PublishedStartTime", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ScheduleEvent"
         } = item, "PublishedStartTime", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("start_time", chars |> parse_datetime())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "PublishedStartTime",
        {%{
           "type" => "ScheduleEvent"
         } = item, "PublishedStartTime", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## live
  def handle_event(
        :start_element,
        {"Live", attrs},
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    new_item =
      case attrs do
        %{"value" => "true"} ->
          item
          |> Helper.merge_list(
            "qualifiers",
            "live"
          )

        _ ->
          item
      end

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ## Repeat
  def handle_event(
        :start_element,
        {"Repeat", attrs},
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {content, materials, airings}, channel}
      ) do
    attrs = Enum.into(attrs, %{})

    new_item =
      case attrs do
        %{"value" => "true"} ->
          item
          |> Helper.merge_list(
            "qualifiers",
            "rerun"
          )

        _ ->
          item
      end

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  ## end_time
  def handle_event(
        :start_element,
        {"PublishedEndTime", _},
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "PublishedEndTime", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "ScheduleEvent"
         } = item, "PublishedEndTime", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("end_time", chars |> parse_datetime())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "PublishedEndTime",
        {%{
           "type" => "ScheduleEvent"
         } = item, "PublishedEndTime", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## Push to map
  def handle_event(
        :end_element,
        "ScheduleEvent",
        {%{
           "type" => "ScheduleEvent"
         } = item, _, {contents, materials, airings}, channel}
      ) do
    cond do
      Map.has_key?(item, "program_id") ->
        program = Map.get(contents, Map.get(item, "program_id", %{})) || %{}
        group = Map.get(materials, Map.get(program, "episode_crid", %{})) || %{}

        {:ok,
         {nil, nil, {contents, materials, [parse_airing(item, program, group) | airings]},
          channel}}

      true ->
        {:ok, {nil, nil, {contents, materials, airings}, channel}}
    end
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

  defp parse_airing(_, nil, _), do: nil

  defp parse_airing(event, program, group) do
    image_group_type =
      Map.get(group, "material", "series")
      |> case do
        "season" -> "season"
        _ -> "series"
      end

    series_images = Map.get(group, "material", []) |> handle_image(image_group_type)
    content_images = Map.get(program, "material", []) |> handle_image("content")

    %{
      start_time: Map.get(event, "start_time"),
      end_time: Map.get(event, "end_time"),
      titles: Map.get(program, "titles", []),
      subtitles: Map.get(program, "subtitles", []),
      descriptions: Map.get(program, "descriptions", []),
      images: Enum.concat(series_images, content_images),
      season: Map.get(program, "season") || parse_season(group),
      episode: Map.get(program, "episode"),
      qualifiers:
        Enum.concat(
          Map.get(event, "qualifiers", []),
          Map.get(program, "qualifiers", [])
        )
      # production_date: content |> Map.get("production_year")
    }
    |> add_credits(program |> Map.get("credits", []))
    |> add_genres(program |> Map.get("genres", []))
  end

  ## Handle a credit
  defp add_credits(airing, []), do: airing

  defp add_credits(airing, credits) do
    results =
      credits
      |> parse_credits()
      |> Enum.reject(&is_nil(&1.type))

    airing
    |> Map.put(:credits, results)
  end

  defp parse_credits([]), do: []

  defp parse_credits([
         %{"first_name" => first_name, "last_name" => last_name, "type" => type} | credits
       ]),
       do: [
         %{person: "#{first_name} #{last_name}", type: parse_credit_type(type)}
         | parse_credits(credits)
       ]

  defp parse_credits([
         %{"first_name" => first_name, "type" => type} | credits
       ]),
       do: [%{person: first_name, type: parse_credit_type(type)} | parse_credits(credits)]

  defp parse_credits([_ | credits]), do: parse_credits(credits)

  defp parse_credit_type("Programleder"), do: "presenter"
  defp parse_credit_type("Medvirkende"), do: "actor"
  defp parse_credit_type(_), do: nil

  # Add genres
  defp add_genres(airing, []), do: airing

  defp add_genres(airing, genres) do
    genres
    |> Enum.reduce(airing, &parse_genre/2)
  end

  defp parse_genre(%{"code" => code, "type" => type}, airing) do
    codes = parse_genre_code(code)

    airing
    |> append_categories(
      Translation.translate_category(
        "TVAnytime_#{type}",
        codes
      )
    )
  end

  defp parse_genre(_, airing), do: airing

  def parse_genre_code(code) do
    [p1 | parts] = code |> String.split(".")

    {vals, _} =
      parts
      |> Enum.map_reduce([p1], fn x, acc ->
        {
          Enum.join([acc, x], "."),
          Enum.join([acc, x], ".")
        }
      end)

    vals
  end

  def remove_episode?(%{program_type: "movie"} = airing),
    do:
      airing
      |> Map.put(:season, nil)
      |> Map.put(:episode, nil)

  def remove_episode?(airing), do: airing

  ## Handle Images

  defp handle_image([], _type), do: []

  defp handle_image(
         [
           %{
             "type" => "urn:metadata:cs:HowRelatedCS:2012:19"
           } = image
           | images
         ],
         type
       ) do
    [
      %ImageManager.Image{
        type: type,
        source:
          image
          |> Map.get("source"),
        copyright:
          image
          |> Map.get("copyrights", [])
          |> parse_image_copyright(),
        author:
          image
          |> Map.get("copyrights", [])
          |> parse_image_authors()
      }
      | handle_image(images, type)
    ]
  end

  defp handle_image([_image | images], type), do: handle_image(images, type)

  ### Parse copyright from list of strings
  defp parse_image_copyright(list) do
    list
    |> Enum.filter(fn str ->
      String.contains?(str, "©")
    end)
    |> List.first()
    |> case do
      nil ->
        nil

      val ->
        val
        |> String.replace("©", "")
        |> Text.norm()
    end
  end

  ### Parse authors from list of strings
  defp parse_image_authors(list) do
    list
    |> Enum.filter(fn str ->
      String.contains?(str, "Foto:")
    end)
    |> Enum.map(fn str ->
      str
      |> String.replace("Foto:", "")
      |> Text.norm()
    end)
  end

  ## Parse Season
  defp parse_season(%{"group_type" => "season"} = group) do
    group
    |> Map.get("member_of", [])
    |> Enum.filter(fn member ->
      crid = Map.get(member, "crid", "")

      # Custom filtering
      if Regex.match?(~r/nrk\.no/, crid) do
        crid == "crid://nrk.no/SesongSerie"
      else
        true
      end
    end)
    |> List.first()
    |> Map.get("index")
    |> case do
      0 -> nil
      val -> val
    end
  end

  defp parse_season(_group), do: nil

  ## Parse datetime

  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string) do
      {:ok, datetime} ->
        datetime
        |> Timex.Timezone.convert("UTC")

      _ ->
        nil
    end
  end

  ## Parse values
  defp parse_text_language("fin"), do: "fi"
  defp parse_text_language("swe"), do: "sv"
  defp parse_text_language("SE"), do: "sv"
  defp parse_text_language("eng"), do: "en"
  defp parse_text_language("EN"), do: "en"
  defp parse_text_language("dan"), do: "da"
  defp parse_text_language("nor"), do: "nb"
  defp parse_text_language(lang), do: lang

  ## Parse text type
  defp parse_text_type(nil), do: "content"
  defp parse_text_type("main"), do: "content"

  defp parse_text_type(type),
    do:
      type
      |> String.replace("Title", "")
      |> Text.norm()
      |> String.downcase()

  # clean up the crids/hrefs
  defp clean_up_href(string),
    do:
      string
      |> String.replace("urn:tva:metadata:cs:", "")
      |> String.replace("urn:metadata:cs:", "")

  defp parse_program_id(string) do
    string
    |> String.replace(~r/#dr\.dk\/(\d+)$/, "")
  end
end
