defmodule Importer.Parser.Helper do
  alias Importer.Helpers.Okay

  def fix_known_errors(string) do
    string
    |> Okay.replace(" & ", " &amp; ")
    |> Okay.replace("&raquo;", "")
    |> Okay.replace("&quot;", "'")
  end

  def reverse_list(items) do
    items
    |> Okay.reject(&is_nil(&1.start_time))
    |> Enum.reverse()
  end

  def sort_by_start_time(items) do
    items
    |> Okay.reject(&is_nil(&1.start_time))
    |> Okay.sort_by(fn a ->
      {a.start_time.year, a.start_time.month, a.start_time.day, a.start_time.hour,
       a.start_time.minute}
    end)
  end

  def merge_list(map, _, ""), do: map
  def merge_list(map, _, nil), do: map

  def merge_list(map, key, add) when is_list(add) do
    {_, new_map} =
      add
      |> Enum.map_reduce(map, fn element, acc ->
        {
          element,
          acc
          |> merge_list(key, element)
        }
      end)

    new_map
  end

  def merge_list(map, key, add) do
    map
    |> Map.put(key, [add | Map.get(map, key, [])] |> Enum.uniq())
  end

  def get_schedule_language(nil), do: nil

  def get_schedule_language(channel) do
    Map.get(channel, :schedule_languages, []) |> List.first() || nil
  end

  def grab_int_from_text(nil), do: nil

  def grab_int_from_text(text) do
    Regex.run(~r/(\d+)/, text, capture: :first)
    |> case do
      [result] -> result
      _ -> nil
    end
  end
end
