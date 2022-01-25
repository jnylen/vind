defmodule Importer.Helpers.TextParser do
  @moduledoc """
  A helper module for parsing a text.
  """

  alias Importer.Helpers.Text

  @doc """
  Simple helper for running regex parsing on a string
  """
  def parse(list, regex_function) when is_list(list) do
    list
    |> Enum.map(&parse(&1, regex_function))
    |> Enum.reduce(fn %{texts: text1, data: data1}, %{texts: text2, data: data2} ->
      %{
        texts: (text1 ++ text2) |> Enum.reject(&is_nil(&1.value)),
        data: merge_with_lists(data1, data2)
      }
    end)
  end

  def parse([], _regex_function), do: []

  def parse(%{value: value} = item, regex_function) when is_map(item) do
    parsed =
      value
      |> split_text()
      |> regex_function.()
      |> combine_text()

    %{
      texts:
        [Map.put(item, :value, Text.empty_string_to_nil(parsed[:text]))]
        |> Enum.reject(&is_nil(&1.value)),
      data: parsed[:data]
    }
  end

  @doc """
  Merge maps that also have lists but do it better as
  otherwise the lists get replaced, we just want to add to the
  list instead
  """
  def merge_with_lists(main_map, data_to_add) when is_map(main_map) when is_map(data_to_add) do
    Map.merge(main_map, data_to_add, fn _k, v1, v2 ->
      if is_list(v1) do
        (v1 ++ v2)
        |> Enum.uniq()
      else
        v1 || v2
      end
    end)
  end

  @doc """
  Don't put nils
  """
  def put_non_nil(map, _, nil), do: map
  def put_non_nil(map, _, ""), do: map
  def put_non_nil(map, _, list) when is_list(list) and length(list) < 1, do: map

  def put_non_nil(map, key, value) do
    map
    |> Map.put(key, value)
  end

  @doc """
  Split a text into an array to loop over
  """
  def split_text(nil), do: []
  def split_text(""), do: []

  def split_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.replace(~r/\x2e/, ".")
    |> String.replace(~r/\r/, ", ")
    |> String.replace(~r/([\?\!])\./, "\\g{1}")
    |> String.replace(~r/\.{3,}/, "::.")
    |> String.replace(~r/([\.\!\?])\s+([\(A-Z���])/, "\\g{1};;\\g{2}")
    |> String.trim()
    |> String.split(";;")
    |> Enum.map(fn string ->
      case Regex.match?(~r/[\.\!\?]$/, string) do
        false -> String.trim(string) <> "."
        true -> string
      end
    end)
  end

  def split_text(_), do: nil

  @doc """
  Join a list of strings to a single text
  """
  def join_text([] = list) when is_list(list), do: nil

  def join_text(list) when is_list(list) do
    list
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.replace("::.", "...")
    |> String.replace(~r/ +/, " ")
    |> String.trim()
  end

  def join_text(_list), do: nil

  @doc """
  Combine a list of returned data from a regex parser into
  a map that can be merged into the database.
  """
  def combine_text(list) do
    %{
      text:
        list
        |> Enum.map(fn {desc, _map_to_merge} ->
          desc
        end)
        |> join_text,
      data:
        list
        |> Enum.map(fn {_desc, map_to_merge} ->
          map_to_merge
        end)
        |> Enum.reduce(fn x, y ->
          Map.merge(x, y, fn _k, v1, v2 ->
            if is_list(v1) do
              v1 ++ [v2]
            else
              [v1] ++ [v2]
            end
          end)
        end)
    }
  end
end
