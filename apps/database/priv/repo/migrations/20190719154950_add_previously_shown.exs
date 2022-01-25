defmodule Database.Repo.Migrations.AddPreviouslyShown do
  use Ecto.Migration

  def change do
    alter table("airings") do
      add(:previously_shown, :map)
    end
  end
end
