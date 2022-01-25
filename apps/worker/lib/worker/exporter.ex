defmodule Worker.Exporter do
  @moduledoc """
  Runs an exporter to export data.
  """
  use TaskBunny.Job

  @impl true
  def timeout, do: 2_400_000

  @impl true
  def queue_key(payload) do
    key = payload |> Map.values() |> Enum.join("_")

    "exporter_#{key}"
  end

  # Batch export
  @impl true
  def perform(%{"exporter" => exporter, "batch" => batch, "channel" => channel}) do
    channel
    |> Exporter.export(batch, exporter)

    :ok
  end

  # Batch export
  @impl true
  def perform(%{"batch" => batch, "channel" => channel}) do
    Application.get_env(:exporter, :list)
    |> Enum.map(fn exporter ->
      enqueue(%{"exporter" => exporter, "batch" => batch, "channel" => channel})
    end)

    :ok
  end

  @impl true
  def perform(%{"channel" => channel, "exporter" => exporter}) do
    channel
    |> Exporter.export(exporter)

    :ok
  end

  @impl true
  def perform(%{"channel" => channel}) do
    Application.get_env(:exporter, :list)
    |> Enum.map(fn exporter ->
      enqueue(%{"exporter" => exporter, "channel" => channel})
    end)

    :ok
  end
end
