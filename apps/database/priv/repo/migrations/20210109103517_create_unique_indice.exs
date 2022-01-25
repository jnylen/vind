defmodule Database.Repo.Migrations.CreateUniqueIndice do
  use Ecto.Migration

  def change do
    create unique_index(:image_files, :source)
    create unique_index(:airings_image_files, [:airing_id, :image_id])
  end
end
