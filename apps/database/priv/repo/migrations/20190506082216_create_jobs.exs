defmodule Database.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table("jobs", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:name, :string)
      add(:starttime, :naive_datetime)
      add(:deleteafter, :naive_datetime)
      add(:duration, :integer)
      add(:success, :boolean)
      add(:message, :string)
      add(:lastok, :string)
      add(:lastfail, :string)

      timestamps()
    end
  end
end
