defmodule Database.Repo.Migrations.AddConfigToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add(:library, :string, null: true)
      remove(:grabber, :string, null: true)
      add(:config, :map, default: %{})
    end
  end
end
