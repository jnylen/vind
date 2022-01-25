defmodule Database.Repo.Migrations.AddUniqueIndexes do
  use Ecto.Migration

  def change do
    create(unique_index("translations_category", [:type, :original]))
    create(unique_index("translations_country", [:type, :original]))
  end
end
