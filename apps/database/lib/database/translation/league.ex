defmodule Database.Translation.League do
  use Database.Schema
  import Ecto.Changeset

  @moduledoc """
  League handler
  """

  schema "translations_league" do
    field(:type, :string)
    field(:original, :string)
    field(:real_name, :string)
    field(:sports_type, :string)

    timestamps()
  end

  def changeset(league, params \\ %{}) do
    league
    |> cast(params, [
      :type,
      :original,
      :real_name,
      :sports_type
    ])
    |> validate_required([:type, :original, :sports_type])

    # |> validate_schema_types
  end
end
