defmodule Database.Repo.Migrations.AddTimestamps do
  use Ecto.Migration

  def change do
    alter table(:image_files) do
      timestamps()
    end
  end
end
