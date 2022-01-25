defmodule Database.Repo.Migrations.CreateRulesChannels do
  use Ecto.Migration

  def change do
    create table(:ftp_rules_channels) do
      add(:channel_id, references(:channels, type: :uuid))
      add(:ftp_rule_id, references(:ftp_rules, type: :uuid))
    end

    create table(:email_rules_channels) do
      add(:channel_id, references(:channels, type: :uuid))
      add(:email_rule_id, references(:email_rules, type: :uuid))
    end

    create(unique_index(:ftp_rules_channels, [:channel_id, :ftp_rule_id]))
    create(unique_index(:email_rules_channels, [:channel_id, :email_rule_id]))
  end
end
