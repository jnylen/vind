defmodule Importer do
  @moduledoc """
  Documentation for Importer.
  """
  alias Importer.Helpers.Job
  alias Database.Network

  @doc """
  Only run a specific channel's import
  """
  def run(channel) when is_bitstring(channel) do
    channel
    |> Network.get_channel!()
    |> run()
  end

  def run(channel) when is_map(channel) do
    Sentry.Context.set_tags_context(%{type: "importer"})
    require Logger

    channel = Database.Repo.get_by(Database.Network.Channel, xmltv_id: channel.xmltv_id)
    config = Database.Network.Channel.config_transform_to(channel.config_list, "map")

    if is_nil(config) || is_nil(channel) do
      Logger.error("Unknown channel: #{channel}")
    else
      _ = Job.insert_or_update("importer", channel.xmltv_id, %{starttime: DateTime.utc_now()})

      channel.library
      |> to_library()
      |> apply(:import_channel, [
        channel,
        config
      ])

      # Needs to be run as it hits the importer module directly (FILES ONLY)
      if Application.get_env(:main, :environment) == :prod do
        Worker.Exporter.enqueue(%{"channel" => channel.xmltv_id})
      end

      # TODO: Calculate duration time between last run and now.

      :ok
    end
  end

  def run(nil), do: {:error, "couldn't get channel in agent"}

  @doc """
  Only short run a specific channel's import
  """
  def short_update(channel) when is_bitstring(channel) do
    channel
    |> Network.get_channel!()
    |> short_update()
  end

  def short_update(channel) when is_map(channel) do
    Sentry.Context.set_tags_context(%{type: "short_update"})
    require Logger

    channel = Database.Repo.get_by(Database.Network.Channel, xmltv_id: channel.xmltv_id)

    # Grab config for importer
    config = Database.Network.Channel.config_transform_to(channel.config_list, "map")

    if is_nil(config) || is_nil(channel) do
      Logger.error("Unknown channel: #{channel}")
    else
      _ = Job.insert_or_update("short_update", channel.xmltv_id, %{starttime: DateTime.utc_now()})

      channel.library
      |> to_library()
      |> apply(:short_update, [
        channel,
        config
      ])

      # Needs to be run as it hits the importer module directly (FILES ONLY)
      if Application.get_env(:main, :environment) == :prod do
        Worker.Exporter.enqueue(%{"channel" => channel.xmltv_id})
      end

      # TODO: Calculate duration time between last run and now.

      :ok
    end
  end

  def short_update(nil), do: {:error, "couldn't get channel in agent"}

  @doc """
  Force an import of a channel, bypassing cache and any imported data
  """

  def force_update(channel) do
    Sentry.Context.set_tags_context(%{type: "importer"})

    channel =
      channel
      |> Network.get_channel!()

    # Grab config for importer
    config = Database.Network.Channel.config_transform_to(channel.config_list, "map")

    # Mark all files as new
    channel
    |> mark_files_as_new()

    # Force an update on the channel
    channel.library
    |> to_library()
    |> apply(:force_update, [
      channel,
      config
    ])

    run(channel)
  end

  @doc """
  Removes all data for a xmltv_id
  """
  def purge_channel(xmltv_id) do
    val =
      xmltv_id
      |> Network.get_channel!()
      |> Database.Network.purge_channel()
      |> purge_channel_files()

    # Return the val that purge returns
    val
  end

  defp purge_channel_files({:ok, channel}) do
    content_cache = Application.get_env(:file_manager, :content_cache)

    ## TODO: Fix for new filestorage
    # Try to remove filestore
    # [file_store, channel.xmltv_id]
    # |> Path.join()
    # |> File.rm_rf()

    # Remove content cache
    [content_cache, channel.xmltv_id, "#{channel.xmltv_id}*"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.map(&File.rm/1)

    :ok
  end

  defp purge_channel_files(_), do: {:error, "channel was unable to be removed"}

  defp mark_files_as_new(channels) when is_list(channels) do
    channels
    |> Enum.map(&mark_files_as_new/1)
  end

  defp mark_files_as_new(channel) do
    Database.Importer.all_files_for_channel(channel.id)
    |> Enum.map(fn file ->
      file
      |> Database.Importer.update_file(%{status: "new"})
    end)
  end

  defp to_library(value), do: String.to_existing_atom("Elixir.Importer.#{value}")
end
