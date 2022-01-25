defmodule Database.Repo.Migrations.AddNewImageColumns do
  use Ecto.Migration

  def change do
    alter table(:image_files) do
      add :file_name, :string, null: true
      add :uploaded, :boolean, default: false

      remove :file_info, :map
    end
  end
end
