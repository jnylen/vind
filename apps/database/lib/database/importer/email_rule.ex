defmodule Database.Importer.EmailRule do
  @moduledoc """
  A table of rules for incoming emails.
  """

  use Database.Schema
  import Ecto.Changeset

  schema "email_rules" do
    # belongs_to(:channel, Database.Network.Channel)

    many_to_many(:channels, Database.Network.Channel,
      join_through: "email_rules_channels",
      on_replace: :delete
    )

    field(:address, Database.Type.Regex)
    field(:file_name, Database.Type.Regex)
    field(:file_extension, Database.Type.Regex)
    field(:subject, Database.Type.Regex)

    timestamps()
  end

  def changeset(batch, params \\ %{}) do
    batch
    |> cast(params, [
      :address,
      :file_name,
      :file_extension,
      :subject
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
