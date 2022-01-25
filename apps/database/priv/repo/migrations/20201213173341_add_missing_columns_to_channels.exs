defmodule Database.Repo.Migrations.AddMissingColumnsToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add(:schedule, :string, default: "@hourly")
      add(:max_period, :map)
      add(:augment, :boolean, default: true)
      add(:sources, {:array, :map}, default: [])
      add(:flags, {:array, :map}, default: [])
      add(:source_channel_id, references(:channels, type: :uuid), null: true)
    end
  end
end
