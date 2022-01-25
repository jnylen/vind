defmodule Database.Repo.Migrations.AddUniqueAiring do
  use Ecto.Migration

  def change do
    create(unique_index("airings", [:channel_id, :start_time]))
  end
end
