defmodule FileManager do
  @moduledoc """
  FileManager keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Temp. solution to migrate old filestore files to the new cloud one.
  """
  alias Shared.File.Helper, as: FSHelper

  def migrate_old_files() do
    file_store = Application.get_env(:file_manager, :file_store)

    file_store
    |> File.ls!()
    |> get_files()
    |> List.flatten()
    |> process()
    |> Enum.reject(fn file ->
      is_nil(file.channel)
    end)
    |> Enum.map(&upload_file!/1)
  end

  defp get_files([]), do: []

  defp get_files([channel | channels]) do
    file_store = Application.get_env(:file_manager, :file_store)
    path = Path.join([file_store, channel, "/"])

    unless File.dir?(path) do
      get_files(channels)
    else
      files = path |> File.ls!()

      [
        Enum.map(files, fn file ->
          Path.join([file_store, channel, file])
        end)
        | get_files(channels)
      ]
    end
  end

  defp process([]), do: []

  defp process([file | files]) do
    filename = Path.basename(file)

    if filename == "00files" || File.dir?(file) || Path.extname(file) == ".zip" do
      process(files)
    else
      channel_xmltv_id = Path.dirname(file) |> Path.split() |> List.last()

      channel = Database.Repo.get_by(Database.Network.Channel, xmltv_id: channel_xmltv_id)

      [
        %{
          channel: channel,
          path: file,
          file_name: filename
        }
        | process(files)
      ]
    end
  end

  defp upload_file!(file) do
    IO.puts("Adding #{file.file_name} to #{file.channel.xmltv_id}")

    FileManager.Uploader.file_record(file.channel, file.path, "old", file.file_name)
    |> insert!(file.path, file.channel, "old")
  end

  defp insert!(nil, _file, _channel, _source), do: :ok

  defp insert!(record_changeset, file, channel, source),
    do: Database.Importer.upload_file(record_changeset, file, channel, source)
end
