defmodule Database.Repo.Migrations.CreateAiringImages do
  use Ecto.Migration

  def change do
    create table(:airings_image_files, primary_key: false) do
      add :airing_id, references(:airings, type: :uuid, on_delete: :delete_all)
      add :image_id, references(:image_files, type: :uuid, on_delete: :delete_all)
    end

    alter table("airings") do
      remove :images
    end

    alter table("image_files") do
      add :checksum, :string, null: true
    end
  end
end
