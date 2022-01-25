defmodule Database.Repo.Migrations.FixReferences do
  use Ecto.Migration

  def up do
    drop(constraint(:channels, "channels_source_channel_id_fkey"))
    alter table(:channels) do
      modify(:source_channel_id, references(:channels, type: :uuid, on_delete: :delete_all), null: true)
    end

    up_func(:ftp_rules_channels, :channel_id, :channels)
    up_func(:ftp_rules_channels, :ftp_rule_id, :ftp_rules)
    up_func(:email_rules_channels, :channel_id, :channels)
    up_func(:email_rules_channels, :email_rule_id, :email_rules)
  end

  def down do
    drop(constraint(:channels, "channels_source_channel_id_fkey"))
    alter table(:channels) do
      modify(:source_channel_id, references(:channels, type: :uuid, on_delete: :nothing), null: true)
    end

    down_func(:ftp_rules_channels, :channel_id, :channels)
    down_func(:ftp_rules_channels, :ftp_rule_id, :ftp_rules)
    down_func(:email_rules_channels, :channel_id, :channels)
    down_func(:email_rules_channels, :email_rule_id, :email_rules)
  end

  defp up_func(table, field, source_relation \\ nil) do
    drop(constraint(table, "#{table}_#{field}_fkey"))

    alter table(table) do
      modify(field, references(source_relation || table, type: :uuid, on_delete: :delete_all), null: false)
    end
  end

  defp down_func(table, field, source_relation \\ nil) do
    drop(constraint(table, "#{table}_#{field}_fkey"))

    alter table(table) do
      modify(field, references(source_relation || table, type: :uuid, on_delete: :nothing), null: false)
    end
  end
end
