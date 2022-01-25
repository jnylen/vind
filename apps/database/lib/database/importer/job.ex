defmodule Database.Importer.Job do
  @moduledoc """
  Maintains job data for importers, exporters etc
  """

  use Database.Schema
  import Ecto.Changeset

  # TODO: Fix!
  @types [
    "importer",
    "augmenter",
    "exporter",
    "worker",
    "short_update"
  ]

  schema "jobs" do
    field(:type, :string)
    field(:name, :string)
    field(:starttime, :utc_datetime)
    field(:deleteafter, :utc_datetime)
    field(:duration, :integer)
    field(:success, :boolean)
    field(:message, :string)
    field(:lastok, :string)
    field(:lastfail, :string)

    timestamps()
  end

  def changeset(job, params \\ %{}) do
    job
    |> cast(params, [
      :type,
      :name,
      :starttime,
      :deleteafter,
      :duration,
      :success,
      :message,
      :lastok,
      :lastfail
    ])
    |> validate_required([:type, :name])
    |> validate_inclusion(:type, @types)
    |> unique_constraint(:unique_job, name: :unique_jobs_type_name_index)

    # |> validate_schema_types
  end
end
