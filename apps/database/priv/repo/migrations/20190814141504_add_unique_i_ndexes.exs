defmodule Database.Repo.Migrations.AddUniqueINdexes do
  use Ecto.Migration

  def change do
    create(unique_index("files", [:channel_id, :file_name]))
    create(unique_index("batches", [:channel_id, :name]))
  end
end
