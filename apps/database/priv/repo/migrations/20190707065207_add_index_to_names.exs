defmodule Database.Repo.Migrations.AddIndexToNames do
  use Ecto.Migration

  def change do
    execute("CREATE INDEX titles_gin ON airings USING GIN (titles);")
    execute("CREATE INDEX subtitles_gin ON airings USING GIN (subtitles);")
    execute("CREATE INDEX sport_gin ON airings USING GIN (sport);")
  end
end
