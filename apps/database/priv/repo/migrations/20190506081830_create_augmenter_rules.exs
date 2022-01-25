defmodule Database.Repo.Migrations.CreateAugmenterRules do
  use Ecto.Migration

  def change do
    create table("augmenter_rules", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:augmenter, :string)
      add(:title, :string)
      add(:title_language, :string)
      add(:otherfield, :string)
      add(:othervalue, :string)
      add(:remoteref, :string)
      add(:matchby, :string)

      timestamps()
    end
  end
end
