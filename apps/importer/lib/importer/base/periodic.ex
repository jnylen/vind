defmodule Importer.Base.Periodic do
  @moduledoc """
  A periodic HTTP importer.

  Should be used for most HTTP calls.
  """

  @callback import_content(
              tuple :: Tuple.t(),
              batch :: %Database.Importer.Batch{},
              channel :: %Database.Network.Channel{},
              content :: Map.t()
            ) :: {:ok, state} | {:error, state}
            when state: any
  @callback short_update(channel :: Map.t(), config :: Map.t()) ::
              {:ok, result} | {:error, result}
            when result: any
  @callback periods(config :: Map.t(), type :: String.t()) :: list
  @callback short_periods(type :: String.t()) :: list
  @callback object_to_url(date :: String.t(), config :: Map.t(), channel :: Map.t()) :: String.t()
  @callback http_client(config :: Map.t(), folder :: String.t()) :: any
  @callback http_login(env :: any, config :: Map.t(), folder :: String.t()) :: any
  @callback http_call(env :: any, url :: String.t(), folder :: Map.t(), batch :: Map.t()) :: any

  defmacro __using__(opts) do
    # Add functions to importers
    quote bind_quoted: [type: opts[:type]] do
      @behaviour Importer.Base.Periodic

      use Importer.Base
      alias Importer.Base.Periodic
      alias Importer.Base.Periodic.Helper, as: PeriodicHelper

      @doc """
      Return the type of the importer type
      """
      def importer_type, do: :periodic

      @doc """
      Force update a whole batch
      """
      @impl true
      defdelegate force_update(grabber_name, config), to: Periodic

      @doc """
      HTTP Client
      """
      @impl true
      defdelegate http_client(config, folder), to: Periodic
      defoverridable http_client: 2

      @doc """
      HTTP Login
      """
      @impl true
      defdelegate http_login(env, config, folder), to: Periodic
      defoverridable http_login: 3

      @doc """
      HTTP Get
      """
      @impl true
      defdelegate http_call(env, url, folder, batch), to: Periodic
      defoverridable http_call: 4

      @doc """
      Specific periods for diffent types, such as
      weeks, days, months.
      """
      @impl true
      defdelegate periods(config, type), to: PeriodicHelper
      defoverridable periods: 2

      @doc """
      Specific short periods for diffent types, such as
      weeks, days, months.
      """
      @impl true
      defdelegate short_periods(type), to: PeriodicHelper
      defoverridable short_periods: 1

      @doc """
      Incoming import_channel from Importer
      """
      @impl true
      defdelegate import_channel(channel, config, module \\ __MODULE__, type \\ unquote(type)),
        to: Periodic

      defoverridable import_channel: 4

      @doc """
      Incoming short update from Importer
      """
      @impl true
      defdelegate short_update(channel, config, module \\ __MODULE__, type \\ unquote(type)),
        to: Periodic

      defoverridable short_update: 4
    end
  end

  alias Database.Importer, as: DataImporter
  alias Importer.Base.Periodic.Helper, as: PeriodicHelper
  alias Importer.Helpers.NewBatch
  alias Shared.ContentCache
  alias Shared.HttpClient

  @doc """
  Forces an update
  """
  def force_update(channel, config) do
    require Logger
    Sentry.Context.add_breadcrumb(%{category: "force_update"})

    # Remove airings
    Logger.debug("[#{channel.xmltv_id}] Removing airings from database..")
    Database.Network.remove_airing_by_channel_id(channel.id)

    # Remove batches
    Logger.debug("[#{channel.xmltv_id}] Removing batches from database..")
    Database.Importer.remove_batches_by_channel_id(channel.id)

    # Remove cached files
    Logger.debug("[#{channel.xmltv_id}] Removing content cache..")

    channel.xmltv_id
    |> ContentCache.delete_files()
  end

  @doc """

  """
  def import_channel(channels, config, module, type) when is_list(channels),
    do: Enum.map(channels, &import_channel(&1, config, module, type))

  def import_channel(channel, config, module, type) when is_map(channel) do
    Sentry.Context.set_tags_context(%{channel: channel.xmltv_id})
    Sentry.Context.set_tags_context(%{module: module |> to_string()})

    # Grab periods
    period_data = apply(module, :periods, [channel.max_period, type])

    Sentry.Context.add_breadcrumb(%{
      message: "got #{period_data |> length()} periods",
      category: "list_periods",
      level: "info"
    })

    period_data
    |> import_data(channel, config, module)
  end

  def short_update(channels, config, module, type) when is_list(channels),
    do: Enum.map(channels, &short_update(&1, config, module, type))

  def short_update(channel, config, module, type) when is_map(channel) do
    Sentry.Context.set_tags_context(%{
      channel: channel.xmltv_id
    })

    Sentry.Context.set_tags_context(%{module: module |> to_string()})

    # Grab periods
    period_data = apply(module, :short_periods, [type])

    Sentry.Context.add_breadcrumb(%{
      message: "got #{period_data |> length()} periods",
      category: "list_periods",
      level: "info"
    })

    period_data
    |> import_data(channel, config, module)
  end

  def http_client(_config, _folder), do: HttpClient.init(%{cookie_jar: CookieJar.new()})
  def http_login(env, _config, _folder), do: env

  def http_call(env, url, folder, batch),
    do:
      env
      |> HttpClient.get(url, %{file_name: batch.name, folder_name: folder})

  # Creates and runs a ton of functions to see what should be run.
  defp import_data(period_data, channel, config, module) do
    # Output the folder path for the grabber
    folder = Path.join(ContentCache.folder(), channel.xmltv_id)

    # Create the folder
    File.mkdir_p!(folder)

    # Initiliaze the http client for the whole grabber.
    # In case we need to login before or something like that.
    httpclient_env =
      case apply(module, :http_client, [config, folder]) do
        {client, _env} -> client
        client -> client
      end

    # First query on the http_client, only for cookies
    try do
      apply(module, :http_login, [httpclient_env, config, folder])
    rescue
      p ->
        Sentry.capture_exception(p,
          stacktrace: __STACKTRACE__
        )

        {:error, "unknown error from login"}
    catch
      p ->
        Sentry.capture_exception(p,
          stacktrace: __STACKTRACE__
        )

        {:error, "unknown error from login"}
    end

    Sentry.Context.add_breadcrumb(%{
      category: "http_client",
      level: "info"
    })

    # Loop over period
    data =
      period_data
      |> import_data(httpclient_env, folder, channel, config, module)

    # Close down the cookie jar
    httpclient_env
    |> case do
      :no_http -> %{}
      val -> val
    end
    |> Map.get(:cookie_jar)
    |> case do
      nil -> nil
      {:ok, jar} -> CookieJar.stop(jar)
      jar -> CookieJar.stop(jar)
    end

    data
  end

  defp import_data([], _, _, _, _, _), do: :ok

  defp import_data([date | dates], httpclient_env, folder, channel, config, module) do
    Sentry.Context.add_breadcrumb(%{
      message: "#{channel.xmltv_id}_#{date}",
      category: "process",
      level: "info"
    })

    # Start batch
    new_batch = NewBatch.start_batch("#{channel.xmltv_id}_#{date}", channel)
    Sentry.Context.set_extra_context(%{batch: "#{channel.xmltv_id}_#{date}"})

    {:ok, %{batch: batch}, _, _} = new_batch

    _env =
      httpclient_env
      |> case do
        :no_http ->
          :no_http

        http_client ->
          module
          |> PeriodicHelper.create_url([date, config, channel])
          |> PeriodicHelper.http_call([http_client, folder, batch])
          |> parse_env_tuple()
      end
      |> case do
        :no_http ->
          module
          |> process_data(:no_http, new_batch, batch, channel, config)
          |> NewBatch.end_batch()
          |> process_batch(batch)

        {:error, _} = error ->
          error

        %Tesla.Env{} = env ->
          # Check status code
          if env.status > 304 || env.status < 200 do
            {:error, "status code invalid: #{env.status}"}
          else
            # Run it to the import content function inside of the module
            if Application.get_env(:main, :environment) != :prod do
              process_data(module, env, new_batch, batch, channel)
            else
              try do
                process_data(module, env, new_batch, batch, channel)
              rescue
                p ->
                  Sentry.capture_exception(p,
                    stacktrace: __STACKTRACE__
                  )

                  {:error, "unknown error"}
              catch
                p ->
                  Sentry.capture_exception(p,
                    stacktrace: __STACKTRACE__
                  )

                  {:error, "unknown error"}
              end
            end
            |> NewBatch.end_batch()
            |> process_batch(batch)
          end

        _val ->
          {:error, "unknown returned value"}
      end

    dates
    |> import_data(httpclient_env, folder, channel, config, module)
  end

  defp parse_env_tuple({_client, env}), do: env
  defp parse_env_tuple(env), do: env

  defp process_batch({:ok, airings}, batch) do
    import Maybe

    DataImporter.update_batch(batch, %{
      status: "ok",
      earliestdate: maybe(List.first(sort_airings(airings)), [:start_time]),
      latestdate: maybe(List.last(sort_airings(airings)), [:start_time]),
      message: nil
    })

    # Run augmenter
    if Application.get_env(:main, :environment) == :prod do
      Worker.Augmenter.enqueue(%{"batch" => batch.id})
    else
      Augmenter.augment(batch)
    end

    {:ok, batch}
  end

  defp process_batch({:error, reason} = returned, batch) do
    # Error
    Sentry.capture_message(
      reason |> parse_error_msg(),
      level: "warning"
    )

    DataImporter.update_batch(batch, %{status: "error", message: reason})
    returned
  end

  defp process_batch(_, batch) do
    # Error
    # Remove added progs
    # Network.remove_airing_by_batch_id(batch.id)

    Sentry.capture_message(
      "unknown error - neither :ok or :error in process_batch",
      level: "warning"
    )

    DataImporter.update_batch(batch, %{
      status: "error",
      message: "unknown error - neither :ok or :error in process_batch (periodic)"
    })

    {:error, "unknown error - neither :ok or :error in process_batch (periodic)"}
  end

  # Check the env if it should be updated or not
  # If it is, run the importer.
  defp process_data(module, %Tesla.Env{} = env, new_batch, batch, channel) do
    require Logger

    if HttpClient.fresh?(env) do
      if Application.get_env(:main, :environment) != :prod do
        Logger.debug("Updating new/fresh data..")
      end

      # Updated/new data
      # Network.remove_airing_by_batch_id(batch)
      apply(module, :import_content, [new_batch, batch, channel, env])
    else
      if Application.get_env(:main, :environment) != :prod do
        Logger.debug("Not updating cached data..")
      end

      ##### CACHED ###
      if Application.get_env(:main, :environment) != :prod do
        # Network.remove_airing_by_batch_id(batch)
        apply(module, :import_content, [new_batch, batch, channel, env])
      else
        # if the status isn't ok, just run it anyway as it probably failed.
        if Map.get(batch, :status) != "ok" do
          apply(module, :import_content, [new_batch, batch, channel, env])
        else
          :skip
        end
      end
    end
  end

  defp process_data(module, :no_http, new_batch, batch, channel, config) do
    # Do some check with batches if it should be updated or not,
    # check nonametv for inspiration
    # Network.remove_airing_by_batch_id(batch)
    apply(module, :import_content, [new_batch, batch, channel, config])
  end

  defp parse_error_msg({:error, msg}) do
    msg |> to_string()
  rescue
    _ -> "unknown error"
  catch
    _ -> "unknown error"
  end

  defp parse_error_msg(msg) do
    msg |> to_string()
  rescue
    _ -> "unknown error"
  catch
    _ -> "unknown error"
  end

  defp sort_airings(airings),
    do:
      airings
      |> Enum.sort_by(fn a ->
        {a.start_time.year, a.start_time.month, a.start_time.day, a.start_time.hour,
         a.start_time.minute}
      end)
end
