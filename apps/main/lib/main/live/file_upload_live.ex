defmodule Main.Live.FileUploadLive do
  use Main, :live_view
  alias Database.{Repo, Importer, Importer.File, Network}
  alias Shared.File.Helper, as: FSHelper

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: :index}} = socket) do
    channels =
      Network.get_all_channels()
      |> Enum.reduce([], fn channel, acc ->
        [
          [key: channel.xmltv_id, value: channel.id]
          | acc
        ]
      end)
      |> Enum.sort_by(fn channel ->
        Keyword.get(channel, :key)
      end)

    {
      :ok,
      socket
      |> assign(:channels, channels)
      |> assign(:channel_id, nil)
      |> assign(:uploaded_files, [])
      |> allow_upload(:files,
        accept: :any,
        max_entries: 10,
        max_file_size: 50_000_000,
        progress: &handle_progress/3,
        auto_upload: true
      )
    }
  end

  defp handle_progress(:files, entry, socket) do
    if entry.done? do
      channel = Network.get_channel!(socket.assigns.channel_id)

      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        checksum = FSHelper.file_checksum(path)

        %File{}
        |> File.changeset(%{
          channel_id: channel.id,
          file_name: entry.client_name,
          status: "new",
          checksum: checksum,
          source: "manual"
        })
        |> Database.Importer.upload_file(
          path,
          channel,
          "manual"
        )
        |> case do
          {:ok, record} ->
            {
              :noreply,
              socket
              |> update(:uploaded_files, &(&1 ++ [record]))
              # |> put_flash(:info, "file #{record.name} uploaded")
            }

          {:error, _, changeset, _} ->
            errors = EctoHelper.pretty_errors(changeset.errors)

            record = %{
              file_name: entry.client_name,
              upload_status: "error",
              upload_message: Enum.join(errors, ",")
            }

            {
              :noreply,
              socket
              |> update(:uploaded_files, &(&1 ++ [record]))
            }
        end
      end)
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", %{"file" => %{"channel_id" => channel_id}}, socket) do
    {
      :noreply,
      socket
      |> assign(:channel_id, channel_id)
    }
  end

  def error_to_string(:too_large), do: "File is too large"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(v), do: v

  def handle_event(_, _, socket), do: {:noreply, socket}
end
