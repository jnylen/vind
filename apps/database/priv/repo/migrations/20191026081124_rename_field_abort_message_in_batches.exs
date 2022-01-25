defmodule Database.Repo.Migrations.RenameFieldAbortMessageInBatches do
  use Ecto.Migration

  def change do
    rename(table("batches"), :abort_message, to: :message)
  end
end
