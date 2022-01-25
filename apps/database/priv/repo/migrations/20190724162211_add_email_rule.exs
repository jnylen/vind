defmodule Database.Repo.Migrations.AddEmailRule do
  use Ecto.Migration

  def change do
    create table("email_rules", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:channel_id, references("channels", type: :uuid))
      add(:address, :string)
      add(:file_name, :string)
      add(:file_extension, :string)
      add(:subject, :string)

      timestamps()
    end
  end
end
