defmodule Database.Repo.Migrations.AddConfigListToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      remove(:config, :map, default: %{})
      add(:config_list, {:array, :map}, default: [])
    end
  end
end
