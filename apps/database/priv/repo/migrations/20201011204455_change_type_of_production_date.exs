defmodule Database.Repo.Migrations.ChangeTypeOfProductionDate do
  use Ecto.Migration

  def change do
    alter table(:airings) do
      remove :production_date
      add :production_date, :date
    end
  end
end
