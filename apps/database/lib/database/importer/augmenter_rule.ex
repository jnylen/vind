defmodule Database.Importer.AugmenterRule do
  @moduledoc """
  Table for augmenter rules for airings.
  """

  use Database.Schema
  import Ecto.Changeset

  schema "augmenter_rules" do
    belongs_to(:channel, Database.Network.Channel)
    field(:augmenter, :string)
    field(:title, Database.Type.Regex)
    field(:title_language, :string)
    field(:otherfield, :string)
    field(:othervalue, Database.Type.Regex)
    field(:remoteref, :string)
    field(:matchby, :string)

    timestamps()
  end

  def changeset(augmenter_rule, params \\ %{}) do
    augmenter_rule
    |> cast(params, [
      :channel_id,
      :augmenter,
      :title,
      :title_language,
      :otherfield,
      :othervalue,
      :remoteref,
      :matchby
    ])

    # |> validate_document_types
  end
end
