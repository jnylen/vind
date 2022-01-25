defmodule Database.Repo.Migrations.CreateBatches do
  use Ecto.Migration

  def change do
    create table("batches", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:status, :string)
      add(:abort_message, :string)

      timestamps()
    end
  end
end
