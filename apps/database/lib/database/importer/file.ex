defmodule Database.Importer.File do
  @moduledoc """
  Table that handles files sent by either email, ftp or added manually or automatically
  """

  use Database.Schema
  use Observable, :notifier
  import Ecto.Changeset

  alias Database.Observers.FileObserver

  schema "files" do
    belongs_to(:channel, Database.Network.Channel)

    field(:file_name, :string)
    field(:status, :string)
    field(:message, :string)
    field(:earliestdate, :utc_datetime)
    field(:latestdate, :utc_datetime)
    field(:checksum, :string)
    field(:attachment, :string)
    field(:source, :string)

    # field(:source_info, :string)

    timestamps()
  end

  observations do
    action(:update, [FileObserver])
  end

  def changeset(file, params \\ %{}) do
    file
    |> cast(params, [
      :channel_id,
      :file_name,
      :status,
      :message,
      :earliestdate,
      :latestdate,
      :checksum,
      :source,
      :attachment
    ])
    |> validate_required([:channel_id, :file_name, :checksum, :source])
    |> unique_constraint(:file_name, name: :files_channel_id_file_name_index)
  end

  def retrieve_attachment(model),
    do: Database.Uploader.File.retrieve(model.attachment, model)
end
