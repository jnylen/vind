defmodule FileManager.Workers.FTP do
  @moduledoc """
  Runs matches on incoming ftp files
  """
  use TaskBunny.Job
  require Logger

  alias FileManager.Uploader

  @impl true
  def timeout, do: 9_000_000_000

  # @impl true
  # def execution_key(%{"type" => "incoming", "directory" => directory}) do
  #   "filestore_ftp_#{directory}"
  # end

  @impl true
  def execution_key(payload) do
    key = payload |> Map.values() |> Enum.join("_")

    "filestore_ftp_#{key}"
  end

  @impl true
  def perform(%{"path" => file_path}) do
    if File.exists?(file_path) do
      results =
        file_path
        |> Uploader.incoming("ftp")

      if results == :ok || (is_list(results) && Enum.member?(results, :ok)) do
        :ok
      else
        {:error, "no OK files in returned value"}
      end
    else
      :ok
    end
  end
end
