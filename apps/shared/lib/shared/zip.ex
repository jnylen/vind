defmodule Shared.Zip do
  @moduledoc """
  Helper for going through ZIP files in a clean way.

  The way to use ZIP:
  1. Open the zip file
  2. Grab file list
  3. Check if any file should be imported
  4. Get the file content
  5. CLOSE the file.
  """

  def open(file_path, options \\ [:memory]) do
    {:ok, pid} =
      file_path
      |> to_charlist()
      |> :zip.zip_open(options)

    pid
  end

  def close(zip) do
    zip
    |> :zip.zip_close()
  end

  @doc """
  List files inside of the zip file (like if you only want a single file)
  """
  def list_files(zip) do
    case :zip.zip_list_dir(zip) do
      {:ok, file_list} ->
        Enum.map(file_list, &parse_filename(&1))
        |> Enum.reject(&is_nil/1)

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Get a single file in in the zip file
  """
  def get(zip) do
    zip
    |> :zip.zip_get()
  end

  def get(zip, file_name) do
    to_charlist(file_name)
    |> :zip.zip_get(zip)
  end

  @doc """
  Unzip a zip into a folder
  """
  def unzip(file_name, options) do
    file_name
    |> to_charlist()
    |> :zip.unzip(options)
  end

  defp parse_filename({:zip_file, file_name, _, _, _, _}) do
    to_string(file_name)
  end

  defp parse_filename(_), do: nil
end
