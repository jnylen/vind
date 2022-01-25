defmodule Database.Repo.Migrations.CreateAirings do
  use Ecto.Migration

  def change do
    create table("airings", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:start_time, :naive_datetime)
      add(:end_time, :naive_datetime)
      add(:descriptions, {:array, :map}, default: [])
      add(:titles, {:array, :map}, default: [])
      add(:subtitles, {:array, :map}, default: [])
      add(:blines, {:array, :map}, default: [])
      add(:category, {:array, :string}, default: [])
      add(:program_type, :string)
      add(:batch_id, references("batches", type: :uuid))
      add(:season, :integer)
      add(:episode, :integer)
      add(:of_episode, :integer)
      add(:production_date, :string)
      add(:qualifiers, {:array, :string}, default: [])
      add(:sport, :map)
      add(:images, {:array, :map}, default: [])
      # add :previously_shown, :map
      add(:url, :string)
      add(:credits, {:array, :map}, default: [])
      add(:metadata, {:array, :map}, default: [])

      timestamps()
    end

    create(index("airings", [:batch_id]))
  end
end
