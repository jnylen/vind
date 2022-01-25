defmodule Worker.Importer do
  @moduledoc """
  Runs an grabber to import data.
  """

  use TaskBunny.Job

  @impl true
  def queue_key(payload) do
    type = payload |> Map.keys() |> List.first() |> to_string()
    key = payload |> Map.values() |> Enum.join("_")

    "importer_#{type}_#{key}"
  end

  @impl true
  def execution_key(%{"channel" => _} = payload) do
    key =
      payload
      |> Map.values()
      |> Enum.join("_")

    "importer_#{key}"
  end

  @impl true
  def execution_key(%{"short_update" => _} = payload) do
    key =
      payload
      |> Map.values()
      |> Enum.join("_")

    "importer_#{key}"
  end

  @impl true
  def execution_key(_), do: nil

  @impl true
  def timeout, do: 2_400_000

  @impl true
  def perform(%{"channel" => channel}) do
    require Logger

    Logger.info("[full] [#{channel}] Running")
    {uSecs, :ok} = :timer.tc(Importer, :run, [channel])
    Logger.info("[full] [#{channel}] Finished in #{uSecs / 1_000_000} seconds")

    :ok
  end

  @impl true
  def perform(%{"short_update" => channel}) do
    require Logger

    Logger.info("[short_update] [#{channel}] Running")
    {uSecs, :ok} = :timer.tc(Importer, :short_update, [channel])
    Logger.info("[short_update] [#{channel}] Finished in #{uSecs / 1_000_000} seconds")

    :ok
  end

  @impl true
  def perform(%{"force_update" => channel}) do
    require Logger

    Logger.info("[force_update] [#{channel}] Running")
    {uSecs, :ok} = :timer.tc(Importer, :force_update, [channel])
    Logger.info("[force_update] [#{channel}] Finished in #{uSecs / 1_000_000} seconds")

    :ok
  end

  def enqueue_many(list) when is_list(list) do
    list
    |> Enum.map(&enqueue(%{"channel" => &1.xmltv_id}))
  end
end
