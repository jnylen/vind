# TODO: Add augmenter augmenting..
defmodule Importer.Base.File do
  @moduledoc """
  A file specific importer. Most commonly files sent via email or ftp.
  """

  @callback import_content(
              channel :: %Database.Network.Channel{},
              file_name :: String.t(),
              file :: String.t()
            ) :: {:ok, state} | {:error, state}
            when state: any

  defmacro __using__(_opts) do
    # Add functions to importers
    quote do
      @behaviour Importer.Base.File

      use Importer.Base
      alias Importer.Base.File, as: BaseFile

      @doc """
      Return the type of the importer type
      """
      def importer_type, do: :file

      @doc """
      Force update a whole batch
      """
      @impl true
      defdelegate force_update(grabber_name, config),
        to: BaseFile

      @doc """
      Incoming short update from Importer
      """
      @impl true
      defdelegate short_update(channel, config, module \\ __MODULE__, type \\ nil),
        to: BaseFile

      @doc """
      Import data
      """
      @impl true
      defdelegate import_channel(channel, config, module \\ __MODULE__, type \\ nil), to: BaseFile
      defoverridable import_channel: 4

      @doc """
      Get a file's content
      """
      def read_file!(file_path),
        do:
          file_path
          |> File.read!()

      @doc """
      Stream the content of a file
      """
      def stream_file!(file_path),
        do:
          file_path
          |> File.stream!([:trim_bom])

      # Delegate file_exists?(_) to File.exists?(_)
      def file_exists?(file_path),
        do:
          file_path
          |> File.exists?()
    end
  end

  # alias Database.Helpers.Airing, as: AiringHelper
  alias Database.Importer, as: DataImporter
  # alias Importer.Base.File.Helper, as: FileHelper
  alias Importer.Helpers.NewBatch

  def force_update(channel, config) do
    require Logger
    Sentry.Context.add_breadcrumb(%{category: "force_update"})

    # Remove airings
    Logger.debug("[#{channel.xmltv_id}] Removing airings from database..")
    Database.Network.remove_airing_by_channel_id(channel.id)

    # Remove batches
    Logger.debug("[#{channel.xmltv_id}] Removing batches from database..")
    Database.Importer.remove_batches_by_channel_id(channel.id)
  end

  def short_update(channels, config, module, type) when is_list(channels),
    do: import_channel(channels, config, module, type)

  def short_update(channel, config, module, type) when is_map(channel),
    do: import_channel(channel, config, module, type)

  def import_channel(channels, config, module, type) when is_list(channels),
    do: Enum.map(channels, &import_channel(&1, config, module, type))

  def import_channel(channel, _config, module, _type) do
    Sentry.Context.set_tags_context(%{channel: channel.xmltv_id})
    Sentry.Context.set_tags_context(%{module: module |> to_string()})

    # Get files
    files =
      channel.id
      |> Database.Importer.get_new_files_by_channel_id()
      |> Database.Repo.preload(:channel)

    Sentry.Context.add_breadcrumb(%{
      message: "found #{files |> length()} files",
      category: "list_files",
      level: "info"
    })

    for file <- files do
      # Add the returned airings to DB
      Sentry.Context.add_breadcrumb(%{
        message: file.file_name,
        category: "process_file",
        level: "info"
      })

      Sentry.Context.set_extra_context(%{file_name: file.file_name})

      if Application.get_env(:main, :environment) != :prod do
        run_import(file, channel, module)
      else
        try do
          run_import(file, channel, module)
        rescue
          p ->
            Sentry.capture_exception(p,
              stacktrace: __STACKTRACE__
            )

            {:error, "unknown crash"}
        catch
          p ->
            Sentry.capture_exception(p,
              stacktrace: __STACKTRACE__
            )

            {:error, "unknown error"}
        end
      end
      |> process_airings()
    end
  end

  # Run through the airings
  defp process_airings({:error, _} = error), do: error
  defp process_airings({:ok, [], file}), do: {:ok, file}

  defp process_airings({:ok, airings, file}) do
    # grouped_airings = FileHelper.group_airings(airings)

    # # Add it based on batch
    # for {k, airings} <- grouped_airings do
    #   batch = DataImporter.get_batch!(k)

    #   # Do we want to do this?
    #   # Remove all airings if we import it as new
    #   Network.remove_airing_by_batch_id(batch.id)

    #   AiringHelper.process_batch(batch, airings)
    #   |> FileHelper.update_batch(batch)
    # end

    # Enqueue augmenters
    airings
    |> Enum.map(fn a ->
      a.batch_id
    end)
    |> Enum.uniq()
    |> Enum.map(fn batch_id ->
      if Application.get_env(:main, :environment) == :prod do
        Worker.Augmenter.enqueue(%{"batch" => batch_id})
      else
        Augmenter.augment(Database.Importer.get_batch!(batch_id))
      end
    end)

    {:ok, file}
  end

  defp run_import(file, channel, module) do
    file
    |> Database.Importer.File.retrieve_attachment()
    |> run_actual_import(file, channel, module)
  end

  defp run_actual_import({:ok, file_attachment}, file, channel, module) do
    import Maybe

    apply(module, :import_content, [channel, file.file_name, file_attachment])
    |> NewBatch.end_batch()
    |> case do
      {:ok, airings} ->
        {:ok, file} =
          DataImporter.update_file(file, %{
            earliestdate: maybe(List.first(sort_airings(airings)), [:start_time]),
            latestdate: maybe(List.last(sort_airings(airings)), [:start_time]),
            message: nil,
            status: "ok"
          })

        {:ok, airings, file}

      {:error, message} ->
        Sentry.capture_message(
          message |> parse_error_msg(),
          level: "warning"
        )

        {:ok, file} =
          DataImporter.update_file(file, %{
            earliestdate: nil,
            latestdate: nil,
            status: "error",
            message: message |> parse_error_msg()
          })

        {:error, file}

      val ->
        Sentry.capture_message(
          val |> parse_error_msg(),
          level: "warning"
        )

        {:ok, file} =
          DataImporter.update_file(file, %{
            earliestdate: nil,
            latestdate: nil,
            status: "error",
            message: val |> parse_error_msg()
          })

        {:error, file}
    end
  end

  defp run_actual_import({:error, :enoent}, file, _channel, _module) do
    DataImporter.update_file(file, %{
      earliestdate: nil,
      latestdate: nil,
      status: "missing",
      message: "File returned missing from storage"
    })

    {:error, :enoent}
  end

  defp run_actual_import(val, file, _channel, _module) do
    DataImporter.update_file(file, %{
      earliestdate: nil,
      latestdate: nil,
      status: "error",
      message: val |> parse_error_msg()
    })

    val
  end

  defp parse_error_msg({:error, msg}) do
    try do
      msg |> to_string()
    rescue
      _ -> "unknown error"
    catch
      _ -> "unknown error"
    end
  end

  defp parse_error_msg(msg) do
    try do
      msg |> to_string()
    rescue
      _ -> "unknown error"
    catch
      _ -> "unknown error"
    end
  end

  # Sort airings by start_time
  defp sort_airings(airings) do
    airings
    |> Enum.sort_by(fn a ->
      {a.start_time.year, a.start_time.month, a.start_time.day, a.start_time.hour,
       a.start_time.minute}
    end)
  end
end
