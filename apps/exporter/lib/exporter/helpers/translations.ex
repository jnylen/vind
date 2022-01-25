defmodule Exporter.Helpers.Translations do
  @moduledoc """
  Sort the translations on where it should be in a xmltv dtd
  """

  def sort(list) when is_list(list) do
    list
    |> Enum.sort(&(calculate_score(&1) > calculate_score(&2)))
  end

  defp type_score("original"), do: 1000
  defp type_score("content"), do: 1
  defp type_score("series"), do: 10
  defp type_score(_), do: 100

  defp value_score(nil), do: 0
  defp value_score(""), do: 0
  defp value_score(val), do: String.length(val)

  defp calculate_score(%{value: value, type: type}), do: type_score(type) + value_score(value)
end
