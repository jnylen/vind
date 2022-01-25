defmodule Database.Repo.Migrations.AddLastUpdated do
  use Ecto.Migration

  def change do
    alter table("batches") do
      add(:last_updated, :utc_datetime)
    end
  end
end
