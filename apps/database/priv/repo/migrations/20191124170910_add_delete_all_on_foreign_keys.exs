defmodule Database.Repo.Migrations.AddDeleteAllOnForeignKeys do
  use Ecto.Migration

  def up do
    batch_up()
    channel_up()
  end

  def down do
    batch_down()
    channel_down()
  end

  ### BATCHES
  defp batch_up do
    # Airings
    drop(constraint(:airings, "airings_batch_id_fkey"))

    alter table(:airings) do
      modify(:batch_id, references(:batches, type: :uuid, on_delete: :delete_all), null: false)
    end
  end

  defp batch_down do
    # Airings
    drop(constraint(:airings, "airings_batch_id_fkey"))

    alter table(:airings) do
      modify(:batch_id, references(:batches, type: :uuid, on_delete: :nothing), null: false)
    end
  end

  ### CHANNELS

  defp channel_up do
    # AR
    drop(constraint(:augmenter_rules, "augmenter_rules_channel_id_fkey"))

    alter table(:augmenter_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end

    # Batches
    drop(constraint(:batches, "batches_channel_id_fkey"))

    alter table(:batches) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end

    # Files
    drop(constraint(:files, "files_channel_id_fkey"))

    alter table(:files) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end

    # Airings
    drop(constraint(:airings, "airings_channel_id_fkey"))

    alter table(:airings) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end

    # Email Rules
    drop(constraint(:email_rules, "email_rules_channel_id_fkey"))

    alter table(:email_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end

    # FTP Rules
    drop(constraint(:ftp_rules, "ftp_rules_channel_id_fkey"))

    alter table(:ftp_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: false)
    end
  end

  defp channel_down do
    # AR
    drop(constraint(:augmenter_rules, "augmenter_rules_channel_id_fkey"))

    alter table(:augmenter_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end

    # Batches
    drop(constraint(:batches, "batches_channel_id_fkey"))

    alter table(:batches) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end

    # Files
    drop(constraint(:files, "files_channel_id_fkey"))

    alter table(:files) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end

    # Airings
    drop(constraint(:airings, "airings_channel_id_fkey"))

    alter table(:airings) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end

    # Email Rules
    drop(constraint(:email_rules, "email_rules_channel_id_fkey"))

    alter table(:email_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end

    # FTP Rules
    drop(constraint(:ftp_rules, "ftp_rules_channel_id_fkey"))

    alter table(:ftp_rules) do
      modify(:channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: false)
    end
  end
end
