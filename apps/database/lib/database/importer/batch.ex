defmodule Database.Importer.Batch do
  @moduledoc """
  The batches for each channel. Handling airings
  """

  use Database.Schema
  import Ecto.Changeset

  schema "batches" do
    belongs_to(:channel, Database.Network.Channel)
    field(:name, :string)
    # datetime
    field(:last_update, :utc_datetime)
    field(:status, :string)
    field(:message, :string)
    field(:earliestdate, :utc_datetime)
    field(:latestdate, :utc_datetime)

    timestamps()
  end

  def changeset(batch, params \\ %{}) do
    batch
    |> cast(params, [
      :channel_id,
      :name,
      :last_update,
      :status,
      :message,
      :earliestdate,
      :latestdate
    ])
    |> validate_required([:channel_id, :name])

    # |> validate_schema_types
  end
end
