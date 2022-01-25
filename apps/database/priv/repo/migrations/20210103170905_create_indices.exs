defmodule Database.Repo.Migrations.CreateIndices do
  use Ecto.Migration

  def change do
    create(index(:airings, :updated_at))
    create(index(:batches, :updated_at))
    create(index(:files, :updated_at))
  end
end
