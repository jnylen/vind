defmodule Database.Repo.Migrations.CreateTransCountry do
  use Ecto.Migration

  def change do
    create table("translations_country", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:original, :string)
      add(:iso_code, :string)

      timestamps()
    end
  end
end
