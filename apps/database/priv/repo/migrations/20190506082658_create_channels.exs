defmodule Database.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table("channels", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:display_names, {:array, :map}, default: [])
      add(:xmltv_id, :string)
      add(:channel_groups, {:array, :string}, default: [])
      add(:grabber, :string)
      add(:export, :boolean)
      add(:grabber_info, :string)
      add(:logo, :string)
      add(:default_prog_type, :string)
      add(:default_category, :string)
      add(:schedule_languages, {:array, :string}, default: [])
      add(:url, :string)

      timestamps()
    end

    create(unique_index(:channels, [:xmltv_id]))
    create(index(:channels, [:grabber]))
  end
end
