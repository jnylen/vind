defmodule Main.PageView do
  use Main, :view

  def format_number(number) do
    number
    |> to_string
    |> String.replace(~r/\d+(?=\.)|\A\d+\z/, fn int ->
      int
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3, 3, [])
      |> Enum.join(",")
      |> String.reverse()
    end)
  end
end
