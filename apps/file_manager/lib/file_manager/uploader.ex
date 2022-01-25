defmodule FileManager.Uploader do
  @moduledoc """
  Handles an incoming  file from any source and inserts it into the database
  and uploads the file to the cloud.
  """

  alias Database.Importer.File, as: DBFile
  alias FileManager.Source.{Mailgun, FTP}
  alias Shared.File.Helper, as: FSHelper
  alias Database.Repo

  def incoming(file_path, "ftp") do
    file_path
    |> parse_ftp_path()
    |> FTP.process()
    |> handle_result()
  end

  def incoming(message_url, "email") do
    message_url
    |> parse_incoming_email()
    |> handle_result()
  end

  defp handle_result({:ok, []}), do: :ok

  defp handle_result({:ok, [result | results] = res}) when is_list(res) do
    # Handle one
    handle_result({:ok, result})

    # Handle many
    handle_result({:ok, results})
  end

  # Handle incoming ftp file
  defp handle_result({:ok, {channels, file_path}}) do
    channels
    |> Enum.map(fn channel ->
      channel
      |> file_record(file_path, "ftp")
      |> insert!(file_path, channel, "ftp")
    end)

    # Only remove if channels isn't empty
    if Enum.count(channels) > 0 do
      File.rm(file_path)
    end
  end

  # Handle incoming email file
  defp handle_result({:ok, {channels, file_name, %{body: body}}}) do
    {:ok, path} = Briefly.create()
    write_file!(path, body)

    channels
    |> Enum.map(fn channel ->
      channel
      |> file_record(path, "email", file_name)
      |> insert!(path, channel, "email")
    end)
  end

  # Error
  defp handle_result({:error, _, _}), do: :ok
  defp handle_result(:ok), do: :ok
  defp handle_result({:ok, _}), do: :ok
  defp handle_result(_), do: :error

  # Create a file changeset
  def file_record(channel, file_path, source, file_name \\ nil) do
    checksum = FSHelper.file_checksum(file_path)
    file_name = (file_name || Path.basename(file_path)) |> parse_file_name()

    file =
      Database.Importer.get_file_by_channel_id_name(
        channel.id,
        file_name
      )

    if file do
      # File exists, do some calcs
      if file.checksum == checksum do
        nil
      else
        files = Database.Importer.all_files_for_channel(channel.id)

        case new_file_name(file_name, checksum, files) do
          {:error, _} ->
            nil

          {:ok, new_filename} ->
            %DBFile{}
            |> DBFile.changeset(%{
              channel_id: channel.id,
              file_name: new_filename,
              status: "new",
              checksum: checksum,
              source: source
            })
        end
      end
    else
      %DBFile{}
      |> DBFile.changeset(%{
        channel_id: channel.id,
        file_name: file_name,
        status: "new",
        checksum: checksum,
        source: source
      })
    end
  end

  defp insert!(nil, _file, _channel, _source), do: :ok

  defp insert!(record_changeset, file, channel, source),
    do: Database.Importer.upload_file(record_changeset, file, channel, source)

  defp parse_ftp_path(file_path) do
    ftp_store = Application.get_env(:file_manager, :ftp_store)

    directory =
      file_path
      |> String.replace(ftp_store, "")
      |> Path.dirname()
      |> String.split("/")
      |> Enum.reject(&is_blank?/1)
      |> List.first()

    %{
      "directory" => directory,
      "path" => file_path,
      "extension" => Path.extname(file_path)
    }
  end

  defp parse_incoming_email(message_url) do
    message_url
    |> Mailgun.get_email()
    |> case do
      {:ok, env} ->
        env
        |> Map.get(:body, "")
        |> Jsonrs.decode()
        |> case do
          {:ok, mail} ->
            mail
            |> Mailgun.process()

          val ->
            val
        end

      val ->
        val
    end
  end

  defp is_blank?(""), do: true
  defp is_blank?(nil), do: true
  defp is_blank?(_), do: false

  defp parse_file_name(string),
    do:
      string
      |> String.codepoints()
      |> Enum.filter(&String.printable?/1)
      |> Enum.join("")

  defp new_file_name(file_name, checksum, files) do
    Enum.reduce_while(1..10_000_000, 1, fn i, acc ->
      new_file_name =
        (Path.rootname(file_name) <> ".#{acc}" <> Path.extname(file_name))
        |> parse_file_name()

      # Find a file in the index
      files
      |> Enum.filter(fn file ->
        file.file_name == new_file_name
      end)
      |> List.first()
      |> case do
        nil ->
          {:halt, {:ok, new_file_name}}

        file ->
          # Is the checksums the same? Then cancel
          # Otherwise continue to find another filename
          if checksum === file.checksum do
            {:halt, {:error, :duplicate}}
          else
            {:cont, acc + i}
          end
      end
    end)
  end

  defp write_file!(path, content) do
    # Add file, its new
    File.open(
      path,
      [:binary, :write],
      fn io ->
        IO.binwrite(io, content)
      end
    )
  end
end
