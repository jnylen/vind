defmodule Database.Repo.Migrations.AddLogosToChannel do
  use Ecto.Migration

  def change do
    alter table("channels") do
      remove(:logo)

      add(:logos, {:array, :map}, default: [])
    end
  end
end
