defmodule Shared.System.List do
  @moduledoc """
  List files in a directory using ls -ls
  """

  @default ["-printf", "%M|%n|%u|%s|%TY-%Tm-%Td %TH:%TM:%TS %Tz|%P\n", "-type", "f"]

  def files(directory, opts \\ []) do
    System.cmd("find", [directory | Enum.concat(opts, @default)])
    |> parse!()
    |> OK.wrap()
  end

  defp parse!({values, _}) do
    values
    |> String.split("\n")
    |> List.pop_at(0)
    |> split_line()
    |> Enum.reject(&is_nil/1)
  end

  defp split_line({_, lines}),
    do:
      lines
      |> Enum.reject(fn i ->
        Regex.match?(~r/sync\-conflict/i, i)
      end)
      |> split_line()

  defp split_line([]), do: []

  defp split_line([line | lines]) do
    [
      line
      |> String.split("|", trim: true)
      |> into_map()
      | split_line(lines)
    ]
  end

  defp into_map([]), do: nil

  defp into_map(line) do
    %{
      "chmod" => Enum.at(line, 0),
      "owner" => Enum.at(line, 2),
      "file_size" => Enum.at(line, 3) |> String.to_integer(),
      "last_modified" =>
        Enum.at(line, 4)
        |> parse_dt(),
      "file_name" => Enum.at(line, 5)
    }
  end

  defp parse_dt(dt) do
    case DateTimeParser.parse_datetime(dt) do
      {:ok, val} -> val
      _ -> nil
    end
  end
end
