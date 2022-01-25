defmodule Worker.Augmenter do
  @moduledoc """
  Runs augmenters on a batch
  """

  use TaskBunny.Job

  @impl true
  def timeout, do: 2_400_000

  @impl true
  def queue_key(payload) do
    key = payload |> Map.values() |> Enum.join("_")

    "augmenter_#{key}"
  end

  @impl true
  def perform(%{"batch" => batch_id}) do
    batch = Database.Repo.get(Database.Importer.Batch, batch_id)

    batch
    |> Augmenter.augment()

    :ok
  end
end
