defmodule Database.Repo.Migrations.AddNewXmltvId do
  use Ecto.Migration

  def change do
    alter table("channels") do
      add(:new_xmltv_id, :string)
    end

    create(unique_index(:channels, [:new_xmltv_id]))
  end
end
