defmodule Database.Repo.Migrations.AddFtpRegex do
  use Ecto.Migration

  def change do
    create table("ftp_rules", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:channel_id, references("channels", type: :uuid))
      add(:directory, :string)
      add(:file_name, :string)
      add(:file_extension, :string)

      timestamps()
    end
  end
end
