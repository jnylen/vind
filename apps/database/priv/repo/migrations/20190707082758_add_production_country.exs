defmodule Database.Repo.Migrations.AddProductionCountry do
  use Ecto.Migration

  def change do
    alter table("airings") do
      add(:production_countries, {:array, :string})
    end
  end
end
