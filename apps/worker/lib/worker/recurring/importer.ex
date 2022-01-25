defmodule Worker.Recurring.Importer do
  @moduledoc """
  Runs a check on what importer to run
  """

  alias Crontab.CronExpression.Parser, as: CronParser
  alias Database.Importer, as: DBImporter
  alias Importer.Helpers.Job

  use TaskBunny.Job

  # Hours when the short updates are allowed to be run.
  @short_updates_hours 8..22

  @impl true
  def timeout, do: 2_400_000

  @impl true
  def perform(_ \\ nil)

  @impl true
  def perform(%{"type" => "short_update"}) do
    # Only run if it is in an allowed hour-frame
    if Enum.member?(@short_updates_hours, DateTime.utc_now().hour) do
      # load config
      channels = Database.Network.Channel |> Database.Repo.all()

      # get last run for that channel, if its nil just run it!
      channels
      |> Enum.map(&update_channel?/1)
    end

    :ok
  end

  @impl true
  def perform(%{"type" => "importer"}) do
    # load config
    channels = Database.Network.Channel |> Database.Repo.all()

    # get last run for that channel, if its nil just run it!
    channels
    |> Enum.map(&import_channel?/1)

    :ok
  end

  @impl true
  def perform(_), do: perform(%{"type" => "importer"})

  # Per channel stuff
  defp import_channel?(channel),
    do: Worker.Importer.enqueue(%{"type" => "importer", "channel" => channel.xmltv_id})

  # Per channel stuff
  defp update_channel?(channel) do
    if is_nil(channel) do
      nil
    else
      # Get library and check what type of library it is
      library_type =
        String.to_existing_atom("Elixir.Importer.#{channel.library}")
        |> apply(:importer_type, [])

      # :periodic means it can be short updated
      # :file means it can only be fully imported
      if library_type == :periodic do
        job = DBImporter.get_job_by_type_and_name!("short_update", channel.xmltv_id)

        if should_run?(channel.xmltv_id, channel.schedule, job) do
          # Update job db
          _ =
            Job.insert_or_update("short_update", channel.xmltv_id, %{
              starttime: DateTime.utc_now()
            })

          # Enqueue
          Worker.Importer.enqueue(%{"type" => "short_update", "channel" => channel.xmltv_id})
        else
          nil
        end
      else
        job = DBImporter.get_job_by_type_and_name!("importer", channel.xmltv_id)

        if should_run?(channel.xmltv_id, channel.schedule, job) do
          # Update job db
          _ =
            Job.insert_or_update("short_update", channel.xmltv_id, %{
              starttime: DateTime.utc_now()
            })

          # Enqueue
          Worker.Importer.enqueue(%{"type" => "importer", "channel" => channel.xmltv_id})
        else
          nil
        end
      end
    end
  end

  # Calculate if it should run, based on crontab schedule
  # and the job data

  defp should_run?(channel_name, nil, _) do
    require Logger

    Logger.error("Missing cronjob schedule for #{channel_name}")

    false
  end

  defp should_run?(_, _, nil), do: true

  defp should_run?(_, cron_schedule, job) do
    {:ok, expression} = CronParser.parse(cron_schedule)

    # is it in the next run range?
    case expression
         |> Crontab.Scheduler.get_next_run_date(job.starttime |> DateTime.to_naive()) do
      {:ok, datetime} ->
        DateTime.to_unix(datetime |> DateTime.from_naive!("Etc/UTC")) <
          DateTime.to_unix(DateTime.utc_now())

      _ ->
        false
    end
  end

  defp to_map(nil), do: nil
  defp to_map(arg), do: arg |> Enum.into(%{})
end
