defmodule Importer.Base.Periodic.Helper do
  @moduledoc """
  Various helpers for PeriodicImporter
  """

  alias Database.Importer, as: DataImporter
  alias Database.Importer.Batch
  alias Database.Network.Channel

  @short_days 3
  @short_months 0
  @short_weeks 0

  @doc """
  Short hand the getter
  """
  def create_url(module, [date, config, channel]) do
    url =
      module
      |> apply(:object_to_url, [date, config, channel])

    {:ok, module, url}
  end

  @doc """
  Do http call
  """
  def http_call({:ok, module, url}, [httpclient_env, folder, batch]) do
    apply(module, :http_call, [httpclient_env, url, folder, batch])
  end

  @doc """
  Creates/Update/Gets an batch
  """
  def batch_cou(%Batch{} = batch, _channel_id, _batch_name), do: batch

  def batch_cou(nil, channel_id, batch_name) do
    # Create
    {:ok, batch} =
      DataImporter.create_batch(%{
        channel_id: channel_id,
        name: batch_name,
        last_update: DateTime.utc_now()
      })

    batch
  end

  def batch_cou(%Channel{id: channel_id}, batch_name) do
    channel_id
    |> DataImporter.get_batch_by_name!(batch_name)
    |> batch_cou(channel_id, batch_name)
  end

  @doc """
  Returns a specific date range
  """
  def periods(%{amount: max_days}, "daily") do
    use Timex

    current_date = Timex.shift(Date.utc_today(), days: -1)

    current_date
    |> Date.range(Date.add(current_date, max_days))
    |> Enum.map(&Timex.format!(&1, "%Y-%m-%d", :strftime))
    |> Enum.uniq()
  end

  def periods(%{amount: max_weeks}, "weekly") do
    use Timex

    current_date = Date.utc_today() |> Timex.beginning_of_week()
    wanted_date = Timex.shift(current_date, weeks: max_weeks) |> Timex.end_of_week()

    periods = Timex.Interval.new(from: current_date, until: wanted_date, right_open: true, left_open: false)
    |> Interval.with_step(days: 7)
    |> Enum.map(&Timex.format!(&1, "%Y-%W", :strftime))
    |> Enum.uniq()


    if Timex.is_leap?(current_date.year) do
      periods
      |> Enum.concat(["#{current_date.year}-53"])
      |> Enum.sort()
    else
      periods
    end
  end

  def periods(%{amount: max_months}, "monthly") do
    use Timex

    current_date = Date.utc_today()
    wanted_date = Timex.shift(current_date, months: max_months)

    current_date
    |> Date.range(wanted_date)
    |> Enum.map(&Timex.format!(&1, "%Y-%m", :strftime))
    |> Enum.uniq()
  end

  def periods(_, "one"), do: ["all"]

  # def periods(_, type),
  #   do: {:error, "no max value for a period found for grabber for type '#{type}'"}

  def periods(val, type) do
    IO.inspect(val)

    {:error, "no max value for a period found for grabber for type '#{type}'"}
  end

  @doc """
  Short periods for every type
  """
  def short_periods("daily") do
    use Timex

    current_date = Timex.shift(Date.utc_today(), days: -1)

    current_date
    |> Date.range(Date.add(current_date, @short_days))
    |> Enum.map(&Timex.format!(&1, "%Y-%m-%d", :strftime))
    |> Enum.uniq()
  end

  def short_periods("weekly") do
    use Timex

    current_date = Date.utc_today()
    wanted_date = Timex.shift(current_date, weeks: @short_weeks)

    current_date
    |> Date.range(wanted_date)
    |> Enum.map(&Timex.format!(&1, "%Y-%W", :strftime))
    |> Enum.uniq()
  end

  def short_periods("monthly") do
    use Timex

    current_date = Date.utc_today()
    wanted_date = Timex.shift(current_date, months: @short_months)

    current_date
    |> Date.range(wanted_date)
    |> Enum.map(&Timex.format!(&1, "%Y-%m", :strftime))
    |> Enum.uniq()
  end

  def short_periods("one"), do: ["all"]
end
