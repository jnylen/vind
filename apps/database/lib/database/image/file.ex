defmodule Database.Image.File do
  @moduledoc """
  The image files that are received from the tv channels.
  And logos.
  """

  use Database.Schema
  import Ecto.Changeset

  alias Database.Helpers.Language

  @types [
    "channel_logo",
    "episode",
    "series",
    "content"
  ]

  @source_types [
    "local",
    "url"
  ]

  @file_types [
    "jpeg",
    "svg",
    "png"
  ]

  schema "image_files" do
    many_to_many(:airings, Database.Network.Airing,
      join_through: "airings_image_files",
      join_keys: [image_id: :id, airing_id: :id]
    )

    field(:source, :string)
    field(:source_type, :string)

    field(:file_type, :string)
    field(:file_name, :string)

    field(:width, :integer)
    field(:height, :integer)

    field(:type, :string)
    field(:copyright, :string)
    field(:author, {:array, :string})
    field(:language, :string)

    field(:checksum, :string)
    field(:uploaded, :boolean)

    timestamps()
  end

  def changeset(file, params \\ %{}) do
    file
    |> cast(params, [
      :source,
      :source_type,
      :file_type,
      :file_name,
      :width,
      :height,
      :type,
      :copyright,
      :author,
      :language,
      :checksum,
      :uploaded
    ])
    |> unique_constraint(:source, name: :image_files_source_index)
    |> validate_required([:source, :type])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:file_type, @file_types)
    |> validate_inclusion(:source_type, @source_types)
    |> validate_inclusion(:language, Language.all())
  end
end
