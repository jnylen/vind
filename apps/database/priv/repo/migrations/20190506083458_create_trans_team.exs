defmodule Database.Repo.Migrations.CreateTransTeam do
  use Ecto.Migration

  def change do
    create table("translations_team", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:sports_type, :string)
      add(:original, :string)
      add(:name, :string)

      timestamps()
    end
  end
end
