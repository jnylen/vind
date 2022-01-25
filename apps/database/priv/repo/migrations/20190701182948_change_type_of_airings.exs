defmodule Database.Repo.Migrations.ChangeTypeOfAirings do
  use Ecto.Migration

  def change do
    alter table("airings") do
      remove(:start_time)
      remove(:end_time)

      add(:start_time, :utc_datetime)
      add(:end_time, :utc_datetime)
    end
  end
end
