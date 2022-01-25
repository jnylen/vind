defmodule Database.Repo.Migrations.RenameLastUpdated do
  use Ecto.Migration

  def change do
    rename(table("batches"), :last_updated, to: :last_update)
  end
end
