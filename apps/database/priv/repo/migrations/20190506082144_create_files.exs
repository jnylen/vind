defmodule Database.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table("files", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:file_name, :string)
      add(:status, :string)
      add(:message, :string)
      add(:earliestdate, :naive_datetime)
      add(:latestdate, :naive_datetime)
      add(:checksum, :string)

      timestamps()
    end
  end
end
