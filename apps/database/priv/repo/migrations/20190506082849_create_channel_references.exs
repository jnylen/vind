defmodule Database.Repo.Migrations.CreateChannelReferences do
  use Ecto.Migration

  def change do
    alter table("augmenter_rules") do
      add(:channel_id, references(:channels, type: :uuid))
    end

    create(index(:augmenter_rules, [:channel_id]))

    alter table("batches") do
      add(:channel_id, references(:channels, type: :uuid))
    end

    create(index(:batches, [:channel_id]))

    alter table("files") do
      add(:channel_id, references(:channels, type: :uuid))
    end

    create(index(:files, [:channel_id]))

    alter table("airings") do
      add(:channel_id, references(:channels, type: :uuid))
    end

    create(index(:airings, [:channel_id]))
  end
end
