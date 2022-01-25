defmodule Importer.Base.File.Helper do
  @moduledoc """
  Helps FileImporter with some stuff
  """

  alias Database.Importer, as: DataImporter
  alias Database.Network

  @spec update_batch(any(), Database.Importer.Batch.t()) ::
          {:error, any()} | {:ok, Database.Importer.Batch.t()}
  def update_batch({:ok, _}, batch) do
    {:ok, batch} = DataImporter.update_batch(batch, %{status: "ok", abort_message: nil})

    # Run augmenter
    # if Application.get_env(:main, :environment) == :prod do
    #   Worker.Augmenter.enqueue(%{"batch" => batch.id})
    # else
    #   Augmenter.augment(batch)
    # end

    {:ok, batch}
  end

  def update_batch({:error, reason}, batch) do
    # Error
    # Remove added progs
    Network.remove_airing_by_batch_id(batch.id)

    DataImporter.update_batch(batch, %{status: "error", abort_message: reason})

    {:error, reason}
  end

  def update_batch(_, batch) do
    # Error
    # Remove added progs
    Network.remove_airing_by_batch_id(batch.id)

    DataImporter.update_batch(batch, %{
      status: "error",
      abort_message: "unknown error - neither :ok or :error in process_batch (file)"
    })

    {:error, "unknown error - neither :ok or :error in process_batch (file)"}
  end

  @doc """
  Group airings by batch_id, and sort it by start_time
  """
  def group_airings(airings) do
    airings
    # |> Enum.sort_by(fn a -> a.start_time end)
    |> Enum.group_by(fn a -> a.batch_id end)
    |> Enum.sort_by(fn {_, g} ->
      d = List.first(g).start_time
      {d.year, d.month, d.day, d.hour, d.minute, d.second}
    end)
  end
end
