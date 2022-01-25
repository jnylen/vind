defmodule Database.Repo.Migrations.AddUniqueIndexToJobs2 do
  use Ecto.Migration

  def change do
    create unique_index(:jobs, [:type, :name], name: :unique_jobs_type_name_index)
  end
end
