defmodule Importer.Parser.PublicSchedule do
  @moduledoc """
  A parser for the Public Schedule V4.2.0 format
  """

  @behaviour Saxy.Handler

  use Importer.Helpers.Translation

  alias Importer.Helpers.Text
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
      |> String.replace("v41:", "")
      |> String.replace("v4:", "")
    end)
    |> Saxy.parse_stream(__MODULE__, {nil, nil, {%{}, %{}, []}, channel})
  end

  def parse(string, channel) when is_bitstring(string) do
    string
    |> String.trim_leading(<<0xFEFF::utf8>>)
    |> Helper.fix_known_errors()
    |> String.replace("v41:", "")
    |> String.replace("v4:", "")
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
        {"content", _},
        {nil, _, {content, materials, airings}, channel}
      ) do
    map = %{
      "type" => "content"
    }

    {:ok, {map, nil, {content, materials, airings}, channel}}
  end

  ## Content ID
  def handle_event(
        :start_element,
        {"contentId", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "contentId", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "contentId", {content, materials, airings}, channel}
      ) do
    {:ok, {item |> Map.put_new("contentId", chars), nil, {content, materials, airings}, channel}}
  end

  ## season Number
  def handle_event(
        :start_element,
        {"seasonNumber", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "seasonNumber", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "seasonNumber", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item |> Map.put_new("seasonNumber", chars |> Text.to_integer()), nil,
      {content, materials, airings}, channel}}
  rescue
    _ -> {:ok, {item, nil, {content, materials, airings}, channel}}
  catch
    _ -> {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "seasonNumber",
        {%{
           "type" => "content"
         } = item, "seasonNumber", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## episodeNumber
  def handle_event(
        :start_element,
        {"episodeNumber", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "episodeNumber", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "episodeNumber", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item |> Map.put_new("episodeNumber", chars |> Text.to_integer()), nil,
      {content, materials, airings}, channel}}
  rescue
    _ -> {:ok, {item, nil, {content, materials, airings}, channel}}
  catch
    _ -> {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "episodeNumber",
        {%{
           "type" => "content"
         } = item, "episodeNumber", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## title
  def handle_event(
        :start_element,
        {"title", attrs},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, %{type: "title", attrs: attrs |> Enum.into(%{})}, {content, materials, airings},
      channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, %{type: "title", attrs: attrs}, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "titles",
        Text.string_to_map(
          chars |> Text.norm(),
          Map.get(attrs, "language") |> parse_text_language(),
          parse_text_type(Map.get(attrs, "original") |> Text.to_boolean(), Map.get(attrs, "type"))
        )
        |> Map.put_new(:original_type, Map.get(attrs, "type"))
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "title",
        {%{
           "type" => "content"
         } = item, %{type: "title", attrs: _}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## description
  def handle_event(
        :start_element,
        {"description", attrs},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, %{type: "description", attrs: attrs |> Enum.into(%{})}, {content, materials, airings},
      channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, %{type: "description", attrs: attrs}, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "descriptions",
        Text.string_to_map(
          chars |> Text.norm(),
          Map.get(attrs, "language") |> parse_text_language(),
          parse_text_type(Map.get(attrs, "original") |> Text.to_boolean(), Map.get(attrs, "type"))
        )
        |> add_length?(attrs)
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "description",
        {%{
           "type" => "content"
         } = item, %{type: "description", attrs: _}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## image
  def handle_event(
        :start_element,
        {"imageRef", attrs},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, %{type: "image", attrs: attrs |> Enum.into(%{})}, {content, materials, airings},
      channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, %{type: "image", attrs: attrs}, {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Helper.merge_list(
        "images",
        %ImageManager.Image{
          type: "content",
          source: chars
        }
      )

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "imageRef",
        {%{
           "type" => "content"
         } = item, %{type: "image", attrs: _}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## creditList
  def handle_event(
        :start_element,
        {"creditList", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"creditList", {nil, %{}}, []}, {content, materials, airings}, channel}}
  end

  # START CREDIT

  def handle_event(
        :start_element,
        {"name", _},
        {%{
           "type" => "content"
         } = item, {"creditList", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"creditList", {"name", map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, {"creditList", {"name", map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"creditList", {"name", map |> Map.put("person", chars |> Text.norm())}, items},
      {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "name",
        {%{
           "type" => "content"
         } = item, {"creditList", {"name", map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"creditList", {nil, map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :start_element,
        {"function", _},
        {%{
           "type" => "content"
         } = item, {"creditList", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"creditList", {"function", map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, {"creditList", {"function", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok,
     {item, {"creditList", {"function", map |> Map.put("type", chars |> Text.norm())}, items},
      {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "function",
        {%{
           "type" => "content"
         } = item, {"creditList", {"function", map}, items}, {content, materials, airings},
         channel}
      ) do
    {:ok, {item, {"creditList", {nil, map}, items}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "credit",
        {%{
           "type" => "content"
         } = item, {"creditList", {_, map}, items}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item, {"creditList", {nil, %{}}, [map | items]}, {content, materials, airings}, channel}}
  end

  # END CREDIT

  def handle_event(
        :end_element,
        "creditList",
        {%{
           "type" => "content"
         } = item, {"creditList", _, credits}, {content, materials, airings}, channel}
      ) do
    {:ok, {item |> Map.put("credits", credits), nil, {content, materials, airings}, channel}}
  end

  ## customProperty
  def handle_event(
        :start_element,
        {"customProperty", [{"key", "category"}]},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"customProperty", "category"}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, {"customProperty", "category"}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Map.put(
        "n_category",
        chars
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "customProperty",
        {%{
           "type" => "content"
         } = item, {"customProperty", _}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## customProperty
  def handle_event(
        :start_element,
        {"customProperty", [{"key", "wideScreen"}]},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, {"customProperty", "wideScreen"}, {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, {"customProperty", "wideScreen"}, {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Map.put(
        "n_ws",
        chars |> Text.to_boolean()
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "customProperty",
        {%{
           "type" => "content"
         } = item, {"customProperty", _}, {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## keyword
  def handle_event(
        :start_element,
        {"keyword", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "keyword", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "keyword", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Helper.merge_list(
        "keywords",
        chars
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "keyword",
        {%{
           "type" => "content"
         } = item, "keyword", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## mainGenre
  def handle_event(
        :start_element,
        {"mainGenre", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "mainGenre", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "mainGenre", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Helper.merge_list(
        "main_genres",
        chars |> cleanup_genres()
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "mainGenre",
        {%{
           "type" => "content"
         } = item, "mainGenre", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## subGenre
  def handle_event(
        :start_element,
        {"subGenre", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "subGenre", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "subGenre", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Helper.merge_list(
        "sub_genres",
        chars |> cleanup_genres()
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "subGenre",
        {%{
           "type" => "content"
         } = item, "subGenre", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## productionYear
  def handle_event(
        :start_element,
        {"productionYear", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "productionYear", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "productionYear", {content, materials, airings}, channel}
      ) do
    new_item =
      if Regex.match?(~r/(?<production_year>\d{4}?)/i, chars) do
        matches =
          Regex.named_captures(
            ~r/(?<production_year>\d{4}?)/i,
            chars
          )

        item
        |> Map.put("production_year", Text.year_to_date(Map.get(matches, "production_year")))
      else
        item
      end

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "productionYear",
        {%{
           "type" => "content"
         } = item, "productionYear", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## treeNode
  def handle_event(
        :start_element,
        {"treeNode", _},
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "treeNode", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "content"
         } = item, "treeNode", {content, materials, airings}, channel}
      ) do
    {:ok,
     {item
      |> Helper.merge_list(
        "tree_nodes",
        chars
      ), nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "treeNode",
        {%{
           "type" => "content"
         } = item, "treeNode", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## Push to map
  def handle_event(
        :end_element,
        "content",
        {%{
           "type" => "content"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok,
     {nil, nil, {content |> Map.put_new(Map.get(item, "contentId"), item), materials, airings},
      channel}}
  end

  ####### events
  def handle_event(
        :start_element,
        {"event", _},
        {nil, _, {content, materials, airings}, channel}
      ) do
    map = %{
      "type" => "event"
    }

    {:ok, {map, nil, {content, materials, airings}, channel}}
  end

  ## live
  def handle_event(
        :start_element,
        {"live", _},
        {%{
           "type" => "event"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "live", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "event"
         } = item, "live", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("live", chars |> Text.to_boolean())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "live",
        {%{
           "type" => "event"
         } = item, "live", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## rerun
  def handle_event(
        :start_element,
        {"rerun", _},
        {%{
           "type" => "event"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "rerun", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "event"
         } = item, "rerun", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("rerun", chars |> Text.to_boolean())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "rerun",
        {%{
           "type" => "event"
         } = item, "rerun", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :start_element,
        {"time", [{"type", "public"}]},
        {map, _, {content, materials, airings}, channel}
      ) do
    {:ok, {Map.put(map, "subtype", "time"), nil, {content, materials, airings}, channel}}
  end

  ## startTime
  def handle_event(
        :start_element,
        {"startTime", _},
        {%{
           "subtype" => "time"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "startTime", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "subtype" => "time"
         } = item, "startTime", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("startTime", chars |> parse_datetime())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "startTime",
        {%{
           "subtype" => "time"
         } = item, "startTime", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## endTime
  def handle_event(
        :start_element,
        {"endTime", _},
        {%{
           "subtype" => "time"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "endTime", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "subtype" => "time"
         } = item, "endTime", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("endTime", chars |> parse_datetime())

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "endTime",
        {%{
           "subtype" => "time"
         } = item, "endTime", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## channelId
  def handle_event(
        :start_element,
        {"channelId", _},
        {%{
           "type" => "event"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "channelId", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "event"
         } = item, "channelId", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("channelId", chars)

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "channelId",
        {%{
           "type" => "event"
         } = item, "channelId", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## contentIdRef
  def handle_event(
        :start_element,
        {"contentIdRef", _},
        {%{
           "type" => "event"
         } = item, _, {content, materials, airings}, channel}
      ) do
    {:ok, {item, "contentIdRef", {content, materials, airings}, channel}}
  end

  def handle_event(
        :characters,
        chars,
        {%{
           "type" => "event"
         } = item, "contentIdRef", {content, materials, airings}, channel}
      ) do
    new_item =
      item
      |> Map.put_new("contentIdRef", chars)

    {:ok, {new_item, nil, {content, materials, airings}, channel}}
  end

  def handle_event(
        :end_element,
        "contentIdRef",
        {%{
           "type" => "event"
         } = item, "contentIdRef", {content, materials, airings}, channel}
      ) do
    {:ok, {item, nil, {content, materials, airings}, channel}}
  end

  ## Push to map
  def handle_event(
        :end_element,
        "event",
        {%{
           "type" => "event"
         } = item, _, {contents, materials, airings}, channel}
      ) do
    cond do
      channel |> Map.get(:grabber_info) |> is_nil() &&
          Map.has_key?(item, "contentIdRef") ->
        content = Map.get(contents, Map.get(item, "contentIdRef", %{}))
        {:ok, {nil, nil, {contents, materials, [parse_airing(item, content) | airings]}, channel}}

      Map.get(channel, :grabber_info) == Map.get(item, "channelId") &&
          Map.has_key?(item, "contentIdRef") ->
        content = Map.get(contents, Map.get(item, "contentIdRef", %{}))
        {:ok, {nil, nil, {contents, materials, [parse_airing(item, content) | airings]}, channel}}

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

  defp add_length?(nil, _), do: nil

  defp add_length?(map, attrs) do
    map
    |> Map.put(:length, Map.get(attrs, "length"))
  end

  defp parse_text_language("fin"), do: "fi"
  defp parse_text_language("swe"), do: "sv"
  defp parse_text_language("eng"), do: "en"
  defp parse_text_language("dan"), do: "da"
  defp parse_text_language("nor"), do: "nb"
  defp parse_text_language("ger"), do: "de"

  defp parse_text_language(language) do
    language
  end

  defp parse_text_type(true, _), do: "original"
  defp parse_text_type(_, type), do: type |> Text.norm()

  ########### Dont forget to add to this one

  def remove_custom_fields(item) do
    item
    |> Map.delete("c_treenodes")
    |> Map.delete("c_keywords")
    |> Map.delete("n_category")
    |> Map.delete("n_ws")
    |> Map.delete("main_genres")
    |> Map.delete("sub_genres")
  end

  defp parse_airing(_, nil), do: nil

  defp parse_airing(airing, content) do
    %{
      start_time: Map.get(airing, "startTime"),
      end_time: Map.get(airing, "endTime"),
      titles: Map.get(content, "titles", []),
      descriptions: Map.get(content, "descriptions", []),
      images: Map.get(content, "images", []),
      season: content |> Map.get("seasonNumber") |> parse_num(),
      episode: content |> Map.get("episodeNumber") |> parse_num(),
      production_date: content |> Map.get("production_year")
    }
    |> Map.put("c_treenodes", content |> Map.get("tree_nodes", []))
    |> Map.put("c_keywords", content |> Map.get("keywords", []))
    |> Map.put("n_category", content |> Map.get("n_category"))
    |> Map.put("n_ws", content |> Map.get("n_ws"))
    |> Map.put("main_genres", content |> Map.get("main_genres", []))
    |> Map.put("sub_genres", content |> Map.get("sub_genres", []))
    |> add_qualifier("rerun", Map.get(airing, "rerun"))
    |> add_qualifier("live", Map.get(airing, "live"))
    |> add_credits(content |> Map.get("credits", []))
  end

  # Add a qualifier
  defp add_qualifier(airing, "rerun", true),
    do:
      airing
      |> Map.put(:qualifiers, (Map.get(airing, :qualifiers) || []) ++ ["rerun"])

  defp add_qualifier(airing, "live", true),
    do:
      airing
      |> Map.put(:qualifiers, (Map.get(airing, :qualifiers) || []) ++ ["live"])

  # return airing if no match
  defp add_qualifier(airing, _, _), do: airing

  # add credits
  defp add_credits(airing, []), do: airing

  defp add_credits(airing, credits) do
    results = parse_credits(credits)

    airing
    |> Map.put(:credits, results)
  end

  defp parse_credits([]), do: []

  defp parse_credits([%{"person" => person, "type" => "actor"} | credits]),
    do: [%{person: person, type: "actor"} | parse_credits(credits)]

  defp parse_credits([%{"person" => person, "type" => "director"} | credits]),
    do: [%{person: person, type: "director"} | parse_credits(credits)]

  defp parse_credits([_ | credits]), do: parse_credits(credits)

  # parse dt
  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string, to_utc: true) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  defp parse_num(0), do: nil
  defp parse_num(nil), do: nil
  defp parse_num(""), do: nil
  defp parse_num(val), do: val

  defp cleanup_genres(text) do
    text
    |> Text.norm()
    |> replace_text("Core: ", "")
    |> replace_text("Non-Scripted: ", "")
    |> replace_text("Sports: ", "")
    |> Text.norm()
  end

  defp replace_text(nil, _, _), do: nil

  defp replace_text(value, replace, with_val) do
    value
    |> String.replace(replace, with_val)
  end
end
