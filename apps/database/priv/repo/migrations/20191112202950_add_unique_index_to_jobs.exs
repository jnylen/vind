defmodule Database.Repo.Migrations.AddUniqueIndexToJobs do
  use Ecto.Migration

  def change do
    create(unique_index("jobs", [:type, :name]))
  end
end
