defmodule Database.Repo.Migrations.ChangeTypeOfFiles do
  use Ecto.Migration

  def change do
    alter table("files") do
      remove(:earliestdate)
      remove(:latestdate)

      add(:earliestdate, :utc_datetime)
      add(:latestdate, :utc_datetime)
    end
  end
end
