defmodule Importer.Helpers.Text do
  @moduledoc """
  Collection of helpers for texts from various sources.
  """

  alias Database.Helpers.Language

  def norm(nil), do: nil
  def norm(""), do: nil

  def norm(text) do
    text
    |> String.trim()
    |> String.replace(~r/^\:/, "")
    |> String.replace(~r/^(\d+)\:/, "")
    |> String.replace("[=]", "")
    |> String.trim()
    |> empty_string_to_nil
    |> multi_space_cleaner
  end

  def multi_space_cleaner(nil), do: nil
  def multi_space_cleaner(""), do: nil

  def multi_space_cleaner(string) do
    string
    |> String.split()
    |> Enum.join(" ")
  end

  @doc """
  Converts different types of string to nil
  """
  def empty_string_to_nil(nil), do: nil
  def empty_string_to_nil(""), do: nil
  def empty_string_to_nil("."), do: nil
  def empty_string_to_nil("!"), do: nil
  def empty_string_to_nil("?"), do: nil
  def empty_string_to_nil(string), do: string

  def cleanup(text) do
    text
  end

  @doc """
  Try to fetch a keyword from a list
  """
  def fetch_key(data, fields, key) do
    case Keyword.get(fields, key) do
      nil -> nil
      keyword -> Enum.at(data, keyword)
    end
  end

  def fetch_map_key(data, fields, key) do
    (fetch_key(data, fields, key) || %{})
    |> Map.get(:value)
  end

  @doc """
  Used with SweetXml. Converts booleans in strings to elixir booleans.
  """
  def transform_to_boolean(arg) do
    SweetXml.transform_by(arg, &to_boolean/1)
  end

  def to_boolean(input) do
    case input do
      'false' ->
        false

      'true' ->
        true

      "N" ->
        false

      "J" ->
        true

      "false" ->
        false

      "true" ->
        true

      "FALSE" ->
        false

      "TRUE" ->
        true

      false ->
        false

      true ->
        true

      '0' ->
        false

      '1' ->
        true

      "0" ->
        false

      "1" ->
        true

      "no" ->
        false

      "yes" ->
        true

      "No" ->
        false

      "Yes" ->
        true

      "F" ->
        false

      "Y" ->
        true

      "" ->
        nil

      nil ->
        nil

      _val ->
        # IO.inspect(val)
        false
    end
  end

  @doc """
  String to a integer
  """
  def to_integer(","), do: nil
  def to_integer(""), do: nil
  def to_integer("-"), do: nil
  def to_integer(nil), do: nil
  def to_integer([]), do: nil
  def to_integer(string) when is_integer(string), do: string

  def to_integer(string) do
    string
    |> String.trim()
    |> case do
      "" ->
        nil

      res ->
        res
        |> String.to_integer()
    end
  end

  def year_to_date(number) do
    number
    |> to_integer()
    |> case do
      nil ->
        nil

      num ->
        num
        |> Date.new(1, 1)
        |> case do
          {:ok, date} ->
            date

          _ ->
            nil
        end
    end
  end

  @doc """
  Convert a single string into the new object format.
  Second param is the default language
  """
  def convert_string(nil, _, _), do: []
  def convert_string("", _, _), do: []

  def convert_string(item, default_language, type) do
    case norm(item) do
      "" ->
        []

      nil ->
        []

      value ->
        [
          %{
            value: value,
            language: default_language,
            type: type
          }
        ]
    end
  end

  def string_to_map(item, default_language, type) do
    convert_string(item, default_language, type)
    |> case do
      [] -> nil
      [val] -> val
    end
  end

  @doc """
  Detect a language using Paasaa but if it doesnt match return nil
  """
  def detect_language(""), do: nil
  def detect_language(nil), do: nil

  def detect_language(string) do
    case Paasaa.detect(string) do
      "und" -> nil
      value -> Language.convert(value |> String.downcase())
    end
  end

  @doc """
  Convert language code from 3 to 2
  """
  def convert_language(nil), do: nil
  def convert_language(""), do: nil

  def convert_language(three) do
    three
    |> Language.convert()
  end

  @doc """
  Split a string with failsafe
  """
  def split(nil, _), do: []
  def split("", _), do: []

  def split(string, splitter) do
    string
    |> String.split(splitter)
  end

  @doc """
    Title case a string
  """
  def title_case(string) do
    string
    |> Recase.to_title()
  end
end
