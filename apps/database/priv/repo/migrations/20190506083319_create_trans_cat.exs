defmodule Database.Repo.Migrations.CreateTransCat do
  use Ecto.Migration

  def change do
    create table("translations_category", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:original, :string)
      add(:category, {:array, :string}, default: [])
      add(:program_type, :string)

      timestamps()
    end
  end
end
