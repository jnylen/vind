defmodule Database.Helpers.Airing do
  alias Database.Network, as: Network

  @moduledoc """
  Airing Helper
  """

  def process_batch(batch, list_of_airings),
    do: add_airing(batch, list_of_airings |> sort_start_time(), nil)

  @doc """
  Vars: batch, list_of_airings, last_airing
  """
  def add_airing(_batch, [], _last_program), do: {:ok, "finished"}

  # TODO: Decomplex this function
  def add_airing(batch, [%{} = airing | list_of_airings], last_program) do
    require Logger

    airing =
      airing
      |> set_type_if_has_episode()
      |> fix_timestamps()

    # Conditions on add or skip
    skip_program =
      cond do
        !Map.has_key?(airing, :titles) || Enum.empty?(airing.titles) ->
          "missing-titles"

        # TODO: ADD ENDING CHECK FOR NON ARRAY [#22]
        List.first(airing.titles)[:value] == "end-of-transmission" ->
          "update-end-time"

        last_program == nil ->
          false

        DateTime.compare(airing.start_time, Timex.now()) == :lt &&
            is_old?(airing.start_time) <= -31 ->
          true

        Map.has_key?(airing, :end_time) && airing.end_time != nil &&
            Enum.member?([:eq, :gt], DateTime.compare(airing.start_time, airing.end_time)) ->
          true

        DateTime.compare(airing.start_time, last_program.start_time) == :eq ->
          true

        DateTime.compare(airing.start_time, last_program.start_time) == :lt ->
          hours_diff = Timex.diff(last_program.start_time, airing.start_time, :hours)
          days_diff = Timex.diff(last_program.start_time, airing.start_time, :days)

          # By adding one day to the start_time, we ended up with a time
          # that is more than 20 hours after the lasttime. This probably means
          # that the start_time hasn't wrapped into a new day, but that
          # there is something wrong with the source-data and the time actually
          # moves backwards in the schedule.
          if days_diff * hours_diff < 20 do
            "add-day"
          else
            true
          end

        true ->
          false
      end

    # Skip or add?
    case skip_program do
      "missing-titles" ->
        Logger.error(
          "[#{airing.channel_id |> get_channel_id()}] Skipping program #{airing.start_time} - missing titles"
        )

        add_airing(batch, list_of_airings, last_program)

      "update-end-time" ->
        add_airing(batch, list_of_airings, airing)

      "add-day" ->
        # Logger.info(
        #   "[#{airing.channel_id |> get_channel_id()}] Adding program (with +1 day) #{
        #     airing.start_time
        #   } - #{List.first(airing.titles).value}",
        #   ansi_color: :green
        # )

        add_airing(batch, list_of_airings, add_to_db(airing |> add_day(), last_program))

      true ->
        # Logger.error(
        #   "[#{airing.channel_id |> get_channel_id()} - b: #{airing.batch_id}] Skipping program #{
        #     airing.start_time
        #   } - #{List.first(airing.titles).value}"
        # )

        add_airing(batch, list_of_airings, last_program)

      false ->
        # ADD
        # Logger.info(
        #   "[#{airing.channel_id |> get_channel_id()}] Adding program #{airing.start_time} - #{
        #     List.first(airing.titles).value
        #   }",
        #   ansi_color: :green
        # )

        add_airing(batch, list_of_airings, add_to_db(airing, last_program))
    end
  end

  def add_airing(_batch, [airing | _list_of_airings], _last_program),
    do: {:error, "Wrong struct name: #{inspect(airing)}"}

  @doc """
  Does a query to the database to fetch the program before it
  in order to update the end_time
  """
  def update_end_time(current_program, %{end_time: nil} = last_program) do
    # Do a query to update the last program before
    # this program so it has the correct end time
    Network.update_airing(
      last_program,
      %{
        end_time: current_program.start_time
      }
    )

    current_program
  end

  def update_end_time(current_program, _), do: current_program

  @doc """
  Too old of a date?
  """
  def is_old?(start) do
    start
    |> Timex.diff(Timex.now(), :days)
  end

  # Set type as series if it has season and episode and no type
  defp set_type_if_has_episode(%{episode: episode, season: season} = airing)
       when not is_nil(episode) and not is_nil(season) do
    if is_nil(Map.get(airing, :program_type)) do
      airing
      |> Map.put(:program_type, "series")
    else
      airing
    end
  end

  defp set_type_if_has_episode(airing), do: airing

  # add to db
  defp add_to_db(airing, last_program) do
    case Network.create_airing(airing) do
      # COULDNT ADD!?
      nil ->
        nil

      {:ok, db} ->
        update_end_time(db, last_program)

      {:error, err} ->
        IO.inspect(err)
        nil

      _ ->
        nil
    end
  end

  # Add a day
  defp add_day(%{start_time: start} = airing) do
    airing
    |> Map.put(:start_time, start |> shift_day())
    |> Map.put(:end_time, Map.get(airing, :end_time) |> shift_day())
  end

  defp shift_day(nil), do: nil
  defp shift_day(date), do: date |> Timex.shift(days: 1)

  defp get_channel_id(cid), do: cid |> Database.Network.get_channel!() |> Map.get(:xmltv_id)

  # Set the timestamps to 00
  defp fix_timestamps(airing) do
    airing
    # |> Map.put(:start_time)
  end

  # Just sort by the start_time so we set the end_time correctly
  defp sort_start_time(airings) when is_list(airings) do
    airings
    |> Enum.sort_by(fn airing ->
      {
        airing.start_time.year,
        airing.start_time.month,
        airing.start_time.day,
        airing.start_time.hour,
        airing.start_time.minute
      }
    end)
  end
end
