defmodule Shared.Utf8 do
  def fixer(text) do
    text
    |> strip_utf_helper([])
  end

  defp strip_utf_helper(<<x::utf8>> <> rest, acc) do
    strip_utf_helper(rest, [x | acc])
  end

  defp strip_utf_helper(<<_x>> <> rest, acc), do: strip_utf_helper(rest, acc)

  defp strip_utf_helper("", acc) do
    acc
    |> :lists.reverse()
    |> List.to_string()
  end
end
