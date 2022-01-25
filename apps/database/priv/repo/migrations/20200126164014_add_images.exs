defmodule Database.Repo.Migrations.AddImages do
  use Ecto.Migration

  def change do
    create table("image_files", primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:source, :string)
      add(:source_type, :string)
      add(:file_type, :string)
      add(:file_info, :map, default: %{})
      add(:width, :integer, default: nil)
      add(:height, :integer, default: nil)
      add(:type, :string)
      add(:copyright, :string)
      add(:author, {:array, :string}, default: [])
      add(:language, :string, default: nil)
    end
  end
end
