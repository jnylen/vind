defmodule FileManager.Handler.FTP do
  use GenServer

  @moduledoc """
  Listens for folder changes
  """

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    {:ok, watcher_pid} = FileSystem.start_link(args)
    FileSystem.subscribe(watcher_pid)
    {:ok, %{watcher_pid: watcher_pid}}
  end

  def handle_info(
        {:file_event, watcher_pid, {path, events}},
        %{watcher_pid: watcher_pid} = state
      ) do
    _ =
      events
      |> Enum.map(&handle_event(&1, path))

    {:noreply, state}
  end

  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    {:noreply, state}
  end

  # File is closed, then import it!
  defp handle_event(:closed, path) do
    ftp_store = Application.get_env(:file_manager, :ftp_store)

    directory =
      path
      |> String.replace(ftp_store, "")
      |> Path.dirname()
      |> String.split("/")
      |> Enum.reject(&is_blank?/1)
      |> List.first()

    # Handle the incoming file
    directory
    |> handle_incoming(path)
  end

  defp handle_event(_, _), do: nil

  defp handle_incoming(directory, path),
    do:
      FileManager.Workers.FTP.enqueue(%{
        "type" => "incoming",
        "directory" => directory,
        "path" => path
      })

  defp is_blank?(""), do: true
  defp is_blank?(nil), do: true
  defp is_blank?(_), do: false
end
