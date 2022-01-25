defmodule Worker.Recurring.LogoChecker do
  @moduledoc """
  Check all channels towards a folder of logos and adds the logos to the database if they
  are missing.
  """

  alias Shared.FileStore

  use TaskBunny.Job

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def perform(_ \\ nil) do
    # update git

    # regenerate pngs

    # get_logos

    # match_channels

    # save_channels
  end

  # Get logos from folder
  def get_logos("vector") do
    folder = "/home/jnylen/channel-logos/vector"

    folder
    |> Shared.System.List.files(["-name", "*.svg"])
    |> process_file(folder, ".svg")
  end

  def get_logos("png") do
    "/home/jnylen/channel-logos/build"
    |> Shared.System.List.files(["-name", "*.png"])
  end

  defp process_file([], _folder, _ext), do: []

  defp process_file([file | files], folder, ext) do
    [channel, type] =
      file
      |> Map.get("file_name", "")
      |> String.replace(ext, "")
      |> String.split("_")

    checksum = FileStore.Helper.file_checksum(Path.join(folder, file["file_name"]))
  end
end
