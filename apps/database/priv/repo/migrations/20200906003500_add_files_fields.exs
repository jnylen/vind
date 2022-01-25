defmodule Database.Repo.Migrations.AddFilesFields do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add(:source, :string, null: true)
      add(:attachment, :string, null: true)
      add(:source_info, :map, default: %{})
    end
  end
end
