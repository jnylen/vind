defmodule Database.Translation.Country do
  @moduledoc """
  Country translations between non-standard names to standardized ISO codes.
  """

  use Database.Schema
  import Ecto.Changeset

  schema "translations_country" do
    field(:type, :string)
    field(:original, :string)
    field(:iso_code, :string)

    timestamps()
  end

  def changeset(country, params \\ %{}) do
    country
    |> cast(params, [
      :type,
      :original,
      :iso_code
    ])
    |> validate_required([:type, :original])
    |> validate_inclusion(
      :iso_code,
      Enum.map(CountryData.all_countries(), fn c -> c["alpha2"] end)
    )

    # |> validate_schema_types
  end
end
