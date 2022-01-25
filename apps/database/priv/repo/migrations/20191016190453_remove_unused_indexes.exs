defmodule Database.Repo.Migrations.RemoveUnusedIndexes do
  use Ecto.Migration

  def change do
    drop(index(:files, [:channel_id]))
    drop(index(:batches, [:channel_id]))
    drop(index(:airings, [:channel_id]))
    execute("DROP INDEX titles_gin;")
    execute("DROP INDEX subtitles_gin;")
    execute("DROP INDEX sport_gin;")
  end
end
