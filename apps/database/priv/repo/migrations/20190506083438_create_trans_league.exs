defmodule Database.Repo.Migrations.CreateTransLeague do
  use Ecto.Migration

  def change do
    create table("translations_league", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:original, :string)
      add(:real_name, :string)
      add(:sports_type, :string)

      timestamps()
    end
  end
end
