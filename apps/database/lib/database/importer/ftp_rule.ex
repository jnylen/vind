defmodule Database.Importer.FtpRule do
  @moduledoc """
  A table of rules for incoming ftp transfers.
  """

  use Database.Schema
  import Ecto.Changeset

  schema "ftp_rules" do
    # belongs_to(:channel, Database.Network.Channel)

    many_to_many(:channels, Database.Network.Channel,
      join_through: "ftp_rules_channels",
      on_replace: :delete
    )

    field(:directory, Database.Type.Regex)
    field(:file_name, Database.Type.Regex)
    field(:file_extension, Database.Type.Regex)

    timestamps()
  end

  def changeset(batch, params \\ %{}) do
    batch
    |> cast(params, [
      :directory,
      :file_name,
      :file_extension
    ])
    |> maybe_put_channels(params)
  end

  defp maybe_put_channels(changeset, []), do: changeset

  defp maybe_put_channels(changeset, attrs) do
    channels = Database.Network.get_channels(get_channels(attrs))
    Ecto.Changeset.put_assoc(changeset, :channels, channels)
  end

  def get_channels(attrs), do: Map.get(attrs, :channels) || Map.get(attrs, "channels")
end
