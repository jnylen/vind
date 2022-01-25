defmodule Worker.Recurring.CleanUpFiles do
  @moduledoc """
  Cleans up old files that are in specific folders.
  For exporters.
  """

  use TaskBunny.Job

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def perform(_ \\ nil) do
    config = Application.get_env(:exporter, :list)

    config
    |> Enum.map(fn exporter ->
      Application.get_env(:exporter, String.to_existing_atom(Macro.underscore(exporter)))
      |> Enum.into(%{})
      |> Map.get(:path)
    end)
    |> get_files()
    |> List.flatten()
    |> Enum.map(&remove_file/1)
    |> Enum.reject(&is_nil/1)

    :ok
  end

  defp get_files([]), do: []

  defp get_files([path | paths]) do
    path
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.concat(get_files(paths))
  end

  defp remove_file(file_path) do
    if is_correct_file?(file_path) do
      [_, date] = file_path |> Path.basename() |> cleanup_filename() |> String.split("_")

      # Remove?
      if date_now() > date |> parse_date() do
        file_path |> File.rm()
      end
    end
  end

  defp is_correct_file?(path) do
    case path |> Path.basename() |> cleanup_filename() |> String.split("_") do
      [_, _] -> true
      _ -> false
    end
  end

  defp cleanup_filename(path) do
    path
    |> String.replace(".xml", "")
    |> String.replace(".json", "")
    |> String.replace(".js", "")
    |> String.replace(".gz", "")
  end

  defp parse_date(date) do
    [year, month, day] = date |> String.split("-")

    {year |> String.to_integer(), month |> String.to_integer(), day |> String.to_integer()}
  end

  defp date_now() do
    dt =
      Date.utc_today()
      |> Timex.shift(days: -1)

    {dt.year, dt.month, dt.day}
  end
end
