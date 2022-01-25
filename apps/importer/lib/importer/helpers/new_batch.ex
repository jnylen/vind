defmodule Importer.Helpers.NewBatch do
  @moduledoc """
  A batch helper similar to nonametv's DataStore Helper.

  Data shared between them are in this format:
  {:ok, batch, date, airings}

  StartBatch
  |> StartDate
  |> AddAiring
  |> EndBatch
  """

  @default_tz "UTC"

  alias Database.Importer, as: DBImporter
  import Ecto.Query, only: [from: 2]

  def dummy_batch, do: {:ok, %{}, %{}, []}

  def same_date?(first_date, second_date) do
    [:eq]
    |> Enum.member?(Date.compare(first_date |> Timex.to_date(), second_date |> Timex.to_date()))
  end

  def greater_date?(_, nil), do: true

  def greater_date?(first_date, second_date) do
    [:gt]
    |> Enum.member?(Date.compare(first_date, second_date |> Timex.to_date()))
  end

  def greater_datetime?(first_date, second_date) do
    [:gt]
    |> Enum.member?(DateTime.compare(first_date, second_date))
  end

  def start_batch(name, channel, timezone \\ @default_tz)

  def start_batch({:error, reason}, _, _), do: {:error, reason}

  def start_batch(name, %{id: channel_id}, timezone), do: start_batch(name, channel_id, timezone)

  def start_batch(name, channel_id, timezone) do
    {:ok, batch} =
      DBImporter.get_batch_by_name!(channel_id, name)
      |> case do
        nil ->
          DBImporter.create_batch(%{
            name: name,
            channel_id: channel_id
          })

        batch ->
          batch
      end
      |> OK.wrap()

    if is_nil(batch) do
      {:error, "start_batch: batch returned nil."}
    else
      returned_value = %{
        batch: batch,
        batch_id: batch.id,
        batch_name: batch.name,
        channel_id: channel_id,
        timezone: timezone || @default_tz
      }

      {:ok, returned_value, %{}, []}
    end
  end

  def start_new_batch?(
        tuple,
        item,
        channel,
        earliest_time \\ "00:00",
        timezone \\ "UTC"
      )

  def start_new_batch?(
        {:ok, _batch, _date, _},
        %{start_time: nil},
        _,
        _,
        _
      ),
      do: {:error, "[start_new_batch] start_time is nil."}

  def start_new_batch?(
        {:ok, _batch, _date, _},
        %{start_time: {:error, _}},
        _,
        _,
        _
      ),
      do: {:error, "[start_new_batch] start_time is an error tuple."}

  def start_new_batch?(
        {:ok, batch, date, _} = tuple,
        %{start_time: start_time},
        channel,
        earliest_time,
        timezone
      ) do
    batch_name = "#{channel.xmltv_id}_#{start_time |> Timex.to_date()}"
    # current_date = Map.get(date, :current_date, ~U[1970-01-02 00:00:00Z])
    last_dt = Map.get(date, :last_dt, earliest_time)

    if is_nil(Map.get(batch, :batch_name)) do
      start_batch(batch_name, channel, timezone)
      |> start_date(start_time, earliest_time)
    else
      # greater_datetime?(start_time, current_date)
      if batch.batch_name != batch_name do
        tuple
        |> end_batch()

        start_batch(batch_name, channel, timezone)
        |> start_date(start_time, last_dt)
      else
        tuple
      end
    end
  end

  def start_new_batch?(
        {:error, reason},
        _,
        _,
        _,
        _
      ),
      do: {:error, reason}

  def start_new_batch?(
        _,
        _,
        _,
        _,
        _
      ),
      do: {:error, "[start_new_batch] not correct format"}

  @doc """
  Set a timezone
  """

  def set_timezone({:error, reason}, _), do: {:error, reason}

  def set_timezone({:ok, batch, date, airings}, timezone) do
    {
      :ok,
      batch
      |> Map.put(:timezone, timezone),
      date,
      airings
    }
  end

  @doc """
  Parse date from batch name
  """

  def date_from_batch_name(%{name: name}) do
    [_, date] = name |> String.split("_")

    date |> Date.from_iso8601()
  end

  def date_from_batch_name(_), do: {:error, "wrong format of data"}

  @doc """
  Start a date
  """

  def start_date(tuple, date, earliest_time \\ "00:00")

  def start_date({:error, reason}, _, _), do: {:error, reason}

  def start_date({:ok, _, _, _} = tuple, %DateTime{} = dt, earliest_time),
    do: start_date(tuple, DateTime.to_date(dt), earliest_time)

  def start_date({:ok, _, _, _} = tuple, %NaiveDateTime{} = dt, earliest_time),
    do: start_date(tuple, NaiveDateTime.to_date(dt), earliest_time)

  def start_date({:ok, _, _, _} = tuple, {:ok, %Date{} = date}, earliest_time),
    do: start_date(tuple, date, earliest_time)

  def start_date({:ok, batch, old_date, airings} = tuple, %Date{} = date, earliest_time) do
    require Logger

    if Map.get(old_date, :current_date) |> Timex.to_date() != date do
      if greater_date?(date, Map.get(old_date, :current_date)) do
        # Commit airings
        # if airings |> length() > 0 do
        #   airings
        #   |> multi_query(batch)
        # end

        # Create the current date with the timezone.
        curr_date =
          date
          |> Timex.to_datetime(batch.timezone)

        # Use the datetime provided or create one
        early_dt =
          if is_map(earliest_time) do
            earliest_time
          else
            curr_date
            |> create_datetime(earliest_time)
          end

        {:ok, batch,
         %{
           current_date: curr_date,
           last_dt: early_dt
         }, airings}
      else
        tuple
      end
    else
      tuple
    end
  end

  def start_date(_, _, _), do: {:error, "start_date: Incoming value can only be the date map."}

  @doc """
  Adds an airing with a date etc
  """

  def add_airing({:error, reason}, _), do: {:error, reason}
  def add_airing(_, airing) when not is_map(airing), do: {:error, "airing is not a map"}

  # Empty titles? Skip!
  def add_airing(tuple, %{titles: []} = airing) do
    require Logger

    Logger.warn("titles is empty: #{airing.start_time}. Skipped.")

    tuple
  end

  def add_airing(tuple, %{start_time: %DateTime{}} = airing) do
    add_airing(
      tuple,
      airing
      |> Map.put(:start_time, Map.get(airing, :start_time) |> Timex.format!("%R", :strftime))
    )
  end

  def add_airing(tuple, %{end_time: %DateTime{}} = airing) do
    add_airing(
      tuple,
      airing
      |> Map.put(:end_time, Map.get(airing, :end_time) |> Timex.format!("%R", :strftime))
    )
  end

  def add_airing(tuple, %{start_time: %NaiveDateTime{}} = airing) do
    add_airing(
      tuple,
      airing
      |> Map.put(:start_time, Map.get(airing, :start_time) |> Timex.format!("%R", :strftime))
    )
  end

  def add_airing(tuple, %{end_time: %NaiveDateTime{}} = airing) do
    add_airing(
      tuple,
      airing
      |> Map.put(:end_time, Map.get(airing, :end_time) |> Timex.format!("%R", :strftime))
    )
  end

  def add_airing(tuple, %{start_time: nil} = airing) do
    require Logger

    Logger.warn("start_time is nil: #{List.first(airing.titles).value}. Skipped.")

    tuple
  end

  def add_airing(tuple, %{start_time: {:error, _}} = airing) do
    require Logger

    Logger.warn("start_time has error tuple: #{List.first(airing.titles).value}. Skipped.")

    tuple
  end

  def add_airing(tuple, %{end_time: {:error, _}} = airing) do
    add_airing(
      tuple,
      airing
      |> Map.put(:end_time, nil)
    )
  end

  def add_airing(tuple, %{titles: "end-of-transmission"}) do
    # DO SOMETHING here

    tuple
  end

  def add_airing(
        {:ok, batch, %{current_date: current_date, last_dt: last_dt} = date, airings},
        %{start_time: start_time} = airing
      )
      when start_time |> is_bitstring() do
    require Logger

    start_time = current_date |> create_datetime(airing |> Map.get(:start_time))

    airing =
      airing
      |> Map.put(
        :credits,
        airing
        |> Map.get(:credits, [])
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(&is_nil(&1.person |> Importer.Helpers.Text.norm()))
      )

    # Is the last_start_time after the current start time?
    cond do
      DateTime.compare(last_dt, start_time) == :gt ->
        new_start_time =
          start_time
          |> Timex.shift(days: 1)

        # Compare new start datetime etc
        compare_days = Timex.diff(new_start_time, last_dt, :days)
        compare_hours = Timex.diff(new_start_time, last_dt, :hours)

        if compare_hours + compare_days * 24 < 20 do
          # Logger.warn("Added a day to start_time!")
          # Logger.info("Added a day - Start Date: #{new_start_time |> Timex.to_date()}")

          # By adding one day to the start_time, we ended up with a time
          # that is less than 20 hours after the lasttime. We assume that
          # this means that adding a day is the right thing to do.

          {
            :ok,
            batch,
            date
            |> Map.put(:last_dt, new_start_time)
            |> Map.put(:current_date, current_date |> Timex.shift(days: 1)),
            airings
          }
          |> calculate_end_time(
            airing
            |> Map.put(:start_time, new_start_time)
          )
        else
          # By adding one day to the start_time, we ended up with a time
          # that is more than 20 hours after the lasttime. This probably means
          # that the start_time hasn't wrapped into a new day, but that
          # there is something wrong with the source-data and the time actually
          # moves backwards in the schedule.

          if Application.get_env(:main, :environment) != :prod do
            Logger.warn(
              "[#{batch.batch_name}] Improbable program start: start: #{new_start_time} (last_dt: #{
                last_dt
              }) - #{List.first(airing.titles).value}. Skipped."
            )
          end

          {:ok, batch, date, airings}
        end

      length(airings) > 0 && DateTime.compare(List.first(airings).start_time, start_time) == :eq ->
        if Application.get_env(:main, :environment) != :prod do
          Logger.warn("[#{batch.batch_name}] Same start_time as last airing. Skipped.")

          Logger.warn(
            "[#{batch.batch_name}] ^ Last: #{List.first(airings).start_time} - #{
              Map.get(List.first(List.first(airings).titles), :value)
            }"
          )

          Logger.warn(
            "[#{batch.batch_name}] ^ Current: #{start_time} - #{
              Map.get(List.first(airing.titles), :value)
            }"
          )
        end

        {:ok, batch, date, airings}

      true ->
        {
          :ok,
          batch,
          date
          |> Map.put(:last_dt, start_time),
          airings
        }
        |> calculate_end_time(
          airing
          |> Map.put(:start_time, start_time)
        )
    end
  end

  def add_airing(_, _), do: {:error, "add_airing: You must call start_date before add_airing."}

  @doc """
  Add a raw airing.
  Meaning no add extra day etc
  """
  def add_raw_airing({:error, reason}, _), do: {:error, reason}
  def add_raw_airing(_, airing) when not is_map(airing), do: {:error, "airing is not a map"}
  def add_raw_airing(tuple, %{titles: []}), do: tuple
  def add_raw_airing(tuple, %{titles: "end-of-transmission"}), do: tuple

  def add_raw_airing(tuple, %{start_time: nil} = airing) do
    require Logger

    Logger.warn("start_time is nil: #{List.first(airing.titles).value}. Skipped.")

    tuple
  end

  def add_raw_airing(tuple, %{start_time: {:error, _}} = airing) do
    require Logger

    Logger.warn("start_time has error tuple: #{List.first(airing.titles).value}. Skipped.")

    tuple
  end

  def add_raw_airing(tuple, %{end_time: {:error, _}} = airing) do
    add_raw_airing(
      tuple,
      airing
      |> Map.put(:end_time, nil)
    )
  end

  def add_raw_airing({:ok, batch, _, airings}, airing) do
    {
      :ok,
      batch,
      %{},
      [
        airing
        |> add_ce(batch)
        | airings
      ]
    }
  end

  # Calculate end time
  defp calculate_end_time({:ok, batch, date, airings}, airing) do
    date.current_date
    |> create_datetime(Map.get(airing, :end_time))
    |> case do
      nil ->
        {
          :ok,
          batch,
          date,
          [
            airing
            |> Map.put(:end_time, nil)
            |> add_ce(batch)
            | airings
          ]
        }

      datetime ->
        if DateTime.compare(date.last_dt, datetime) == :gt do
          correct_dt =
            datetime
            |> Timex.shift(days: 1)

          current_date = date.current_date |> Timex.shift(days: 1)

          {
            :ok,
            batch,
            date
            |> Map.put(:current_date, current_date)
            |> Map.put(:last_dt, correct_dt),
            [
              airing
              |> Map.put(:end_time, correct_dt)
              |> add_ce(batch)
              | airings
            ]
          }
        else
          {
            :ok,
            batch,
            date
            |> Map.put(:last_dt, datetime),
            [
              airing
              |> Map.put(:end_time, datetime)
              |> add_ce(batch)
              | airings
            ]
          }
        end
    end
  end

  defp add_ce(airing, batch) do
    airing =
      airing
      |> Map.put(:channel_id, batch.channel_id)
      |> Map.put(:batch_id, batch.batch_id)
      |> Map.put(:start_time, Map.get(airing, :start_time) |> convert_to_utc())
      |> Map.put(:end_time, Map.get(airing, :end_time) |> convert_to_utc())
      |> validate_program_type()

    if compare_datetimes(airing |> Map.get(:start_time), airing |> Map.get(:end_time)) do
      airing
      |> Map.put(:end_time, nil)
    else
      airing
    end
  end

  @doc """
  Ends a batch and return the correct format
  """

  def end_batch({:error, reason}), do: {:error, reason}
  def end_batch(:skip), do: {:ok, []}

  def end_batch({:ok, %{batch_name: batch_name} = batch, _, airings}) do
    Sentry.Context.set_extra_context(%{batch: batch_name})

    if airings |> length() > 0 do
      airings
      |> Importer.Parser.Helper.sort_by_start_time()
      |> multi_query(batch)
    else
      Sentry.Context.add_breadcrumb(%{
        message: "[#{batch.batch_name}] no airings provided",
        category: "airings",
        level: "warn"
      })

      {:error, "no airings provided"}
    end
  end

  def end_batch({:ok, %{}, %{}, []}), do: {:ok, []}

  def end_batch(_) do
    Sentry.capture_message(
      "end_batch: not correct format returned",
      level: "warning"
    )

    {:error, "end_batch: not correct format returned"}
  end

  # Handle the inserts
  defp multi_query(airings, batch) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_all,
      from(a in Database.Network.Airing, where: a.batch_id == ^batch.batch_id)
    )
    |> insert_airings(airings)
    |> Database.Repo.transaction(timeout: 60_000)
    |> case do
      {:ok, inserts} ->
        # Insert images
        airings
        |> Importer.Parser.Helper.sort_by_start_time()
        |> Enum.uniq_by(fn airing ->
          {airing.start_time.year, airing.start_time.month, airing.start_time.day,
           airing.start_time.hour, airing.start_time.minute}
        end)
        |> insert_images(inserts)

        Sentry.Context.add_breadcrumb(%{
          message:
            "[#{batch.batch_name}] #{
              inserts
              |> Map.delete(:delete_all)
              |> Map.values()
              |> Enum.reject(&is_nil/1)
              |> Enum.reject(&is_nil(&1.id))
              |> length()
            } airings added.",
          category: "airings",
          level: "info"
        })

        # Warn about airings not added
        if inserts
           |> Map.delete(:delete_all)
           |> Map.values()
           |> Enum.reject(&is_nil/1)
           |> Enum.filter(&is_nil(&1.id))
           |> length() > 0 do
          Sentry.Context.add_breadcrumb(%{
            message:
              "[#{batch.batch_name}] #{
                inserts
                |> Map.delete(:delete_all)
                |> Map.values()
                |> Enum.reject(&is_nil/1)
                |> Enum.filter(&is_nil(&1.id))
                |> length()
              } airings skipped due to missing id.",
            category: "airings",
            level: "error"
          })
        end

        # Return the list of airings added
        inserts
        |> Map.delete(:delete_all)
        |> Map.values()
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(&is_nil(&1.id))
        |> OK.wrap()

      {:error, failed_op, failed_val, _} ->
        Sentry.capture_message(
          "[#{batch.batch_name}] Insert of airing #{failed_op} failed.",
          level: "warning",
          extra: %{
            start_time: failed_op,
            end_time: Map.get(Map.get(failed_val, :changes, %{}), :end_time),
            errors: failed_val |> Database.Helpers.Changeset.errors_to_map()
          }
        )

        {:error, "Insert of airing #{failed_op} failed."}
    end
  end

  # Create dt
  defp create_datetime(_, nil), do: nil

  defp create_datetime(datetime, time) do
    [hour, minute] =
      case time |> String.split(":") do
        [hour, minute] -> [hour, minute]
        [hour, minute, second] -> [hour, minute]
        _ -> nil
      end

    datetime
    |> Timex.set(
      hour: hour |> String.to_integer(),
      minute: minute |> String.to_integer()
    )
  end

  defp convert_to_utc(nil), do: nil

  defp convert_to_utc(datetime) do
    datetime
    |> Timex.Timezone.convert("UTC")
  end

  # Airings
  defp insert_airings(tuple, airings) do
    airings
    |> Importer.Parser.Helper.sort_by_start_time()
    |> Enum.uniq_by(fn airing ->
      {airing.start_time.year, airing.start_time.month, airing.start_time.day,
       airing.start_time.hour, airing.start_time.minute}
    end)
    |> add_end_time(nil)
    |> insert_multiple(tuple)
  end

  # To Ecto Multi
  defp add_end_time([], last_airing) when is_map(last_airing), do: [last_airing]
  defp add_end_time([], _), do: []

  defp add_end_time([airing | airings], last_airing) do
    changeset =
      if not is_nil(last_airing) && is_nil(Map.get(last_airing, :end_time)) do
        last_airing
        |> Map.put(:end_time, Map.get(airing, :start_time))
      else
        last_airing
      end

    if Map.get(airing, :titles) == "end-of-transmission" do
      [changeset | add_end_time(airings, nil)]
    else
      [changeset | add_end_time(airings, airing)]
    end
    |> Enum.reject(&is_nil/1)
  end

  defp insert_multiple(entries, tuple) do
    Enum.reduce(entries, tuple, fn entry, multi ->
      multi
      |> Ecto.Multi.insert(
        entry.start_time,
        %Database.Network.Airing{}
        |> Database.Network.Airing.changeset(entry),
        on_conflict: :nothing
      )
    end)
  end

  defp insert_images(airings, db_entries) do
    airings
    |> Enum.map(fn airing ->
      db_airing =
        db_entries
        |> Map.get(airing.start_time)

      (Map.get(airing, :images) || [])
      |> Enum.map(fn image ->
        Worker.Imager.enqueue(
          %{
            "airing_id" => db_airing.id,
            "image" =>
              image
              |> Map.from_struct()
              |> Map.Helpers.stringify_keys()
          },
          delay: 120_000
        )
      end)

      {:ok, nil}
    end)
  end

  defp insert_images(multi, _), do: multi

  def compare_datetimes(nil, _), do: false
  def compare_datetimes(_, nil), do: false

  def compare_datetimes(first_date, second_date) do
    [:gt, :eq]
    |> Enum.member?(DateTime.compare(first_date, second_date))
  end

  defp validate_program_type(%{program_type: "movie"} = airing) do
    if is_nil(Map.get(airing, :episode)) && is_nil(Map.get(airing, :season)) do
      airing
    else
      airing
      |> Map.put(:program_type, "series")
    end
  end

  defp validate_program_type(airing), do: airing
end
