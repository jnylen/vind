defmodule Database.Repo.Migrations.AddFieldsToBatch do
  use Ecto.Migration

  def change do
    alter table("batches") do
      add(:earliestdate, :naive_datetime)
      add(:latestdate, :naive_datetime)
    end
  end
end
