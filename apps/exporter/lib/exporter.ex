defmodule Exporter do
  @moduledoc """
  Documentation for Exporter.
  """

  alias Importer.Helpers.Job

  def export(channel, exporter) do
    require Logger

    channel_db = Database.Network.get_channel!(channel)

    if channel_db do
      Job.insert_or_update(
        "exporter",
        "#{exporter |> String.downcase()}_#{channel_db.xmltv_id}",
        %{starttime: DateTime.utc_now()}
      )

      "Elixir.Exporter.#{exporter}"
      |> String.to_existing_atom()
      |> apply(:process, [
        channel_db,
        exporter
      ])

      # TODO: Add duration after finish
    else
      Logger.error("Unknown channel: #{channel}")
    end
  end

  def export(channel, batch, exporter) do
    require Logger
    channel_db = Database.Network.get_channel!(channel)
    batch_db = Database.Repo.get(Database.Importer.Batch, batch)

    if channel_db do
      Job.insert_or_update(
        "exporter",
        "#{exporter |> String.downcase()}_#{channel_db.xmltv_id}",
        %{starttime: DateTime.utc_now()}
      )

      "Elixir.Exporter.#{exporter}"
      |> String.to_existing_atom()
      |> apply(:process, [
        channel_db,
        batch_db,
        exporter
      ])

      # TODO: Add duration after finish
    else
      Logger.error("Unknown channel: #{channel}")
    end
  end

  def export_channels(exporter) do
    Job.insert_or_update(
      "exporter",
      "#{exporter |> String.downcase()}_channels",
      %{starttime: DateTime.utc_now()}
    )

    "Elixir.Exporter.#{exporter}"
    |> String.to_existing_atom()
    |> apply(:process_channels, [
      exporter
    ])
  end

  def export_channels(group, exporter) do
    Job.insert_or_update(
      "exporter",
      "#{exporter |> String.downcase()}_channels",
      %{starttime: DateTime.utc_now()}
    )

    "Elixir.Exporter.#{exporter}"
    |> String.to_existing_atom()
    |> apply(:process_channels, [
      group,
      exporter
    ])
  end

  def escape_binary(val) do
    val
    |> String.chunk(:printable)
    |> Enum.filter(&String.printable?/1)
    |> Enum.join()
    |> String.split()
    |> Enum.join(" ")
  end
end
