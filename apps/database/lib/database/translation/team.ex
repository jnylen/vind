defmodule Database.Translation.Team do
  @moduledoc """
  Team translations between non-standard names to standardized names.
  """

  use Database.Schema
  import Ecto.Changeset

  schema "translations_team" do
    field(:type, :string)
    field(:sports_type, :string)
    field(:original, :string)
    field(:name, :string)

    timestamps()
  end

  def changeset(team, params \\ %{}) do
    team
    |> cast(params, [
      :type,
      :original,
      :name,
      :sports_type
    ])
    |> validate_required([:type, :original, :sports_type])

    # |> validate_schema_types
  end
end
