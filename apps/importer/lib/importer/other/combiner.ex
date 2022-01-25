defmodule Importer.Other.Combiner do
  use Importer.Base.Periodic, type: "daily"
  alias Importer.Helpers.NewBatch
  alias Database.Network
  alias Database.Repo
  alias Importer.Helpers.Database, as: DBHelper

  @doc """
  For non http, just return :no_http
  """
  @impl true
  def http_client(_config, _folder), do: :no_http

  @impl true
  def object_to_url(_, _, _), do: nil

  @doc """
  Function to handle inputted data from the Importer Base

  """
  @impl true
  def import_content(tuple, batch, channel, config) do
    [_, date] = batch.name |> String.split("_")

    # Get airings from another channel and do the flag changes
    airings =
      channel
      |> get_airings(date |> Date.from_iso8601!() |> Timex.to_datetime(:utc))

    tuple
    |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    |> process_airings(airings)
  end

  defp process_airings(tuple, []), do: tuple

  defp process_airings(tuple, [airing | airings]) do
    tuple
    |> NewBatch.add_airing(airing)
    |> process_airings(airings)
  end

  defp get_airings(config, datetime) do
    import Ecto.Query, only: [from: 2]

    source_channels =
      config.sources
      |> list_channels()
      |> Enum.uniq()
      |> Enum.map(&Network.get_channel!/1)
      |> Enum.reject(&is_nil/1)

    source_channels_ids = source_channels |> Enum.reject(&is_nil/1) |> Enum.map(& &1.id)

    if source_channels_ids |> Enum.empty?() do
      []
    else
      max_datetime =
        datetime
        |> Timex.set(
          hour: 23,
          minute: 59,
          second: 59
        )

      from(a in Network.Airing,
        where: a.channel_id in ^source_channels_ids,
        where: a.start_time >= ^datetime,
        where: a.start_time <= ^max_datetime,
        order_by: a.start_time,
        preload: [:image_files]
      )
      |> Repo.all()
      |> combine!(datetime, config.sources, source_channels)
      |> Enum.map(&DBHelper.clean_up_airing/1)
    end
  end

  defp combine!(airings, datetime, source_channels, channels) do
    reoccurences = matches(source_channels, datetime)

    airings
    |> Enum.filter(fn a ->
      reoccurences
      |> Enum.filter(fn occ ->
        a.channel_id == get_channel(channels, occ.xmltv_id) &&
          Timex.after?(a.start_time, occ.start_dt) && Timex.before?(a.start_time, occ.end_dt)
      end)
      |> return_map()
    end)
  end

  # Return only xmltvids
  defp list_channels(config), do: config |> Enum.map(& &1.xmltv_id)

  # Get a single channel
  defp get_channel(channels, xmltv_id),
    do:
      channels
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn c -> c.xmltv_id == xmltv_id end)
      |> get_channel()

  # Return map
  defp return_map([]), do: nil
  defp return_map(list) when is_list(list), do: list |> List.first()

  defp get_channel([]), do: nil
  defp get_channel(list) when is_list(list), do: list |> return_map() |> Map.get(:id)

  defp matches(sources, datetime) do
    day_name = datetime |> Date.day_of_week() |> dayweek_to_string()

    sources
    |> Enum.filter(fn source ->
      Enum.member?(["all", day_name], source.day)
    end)
    |> Enum.map(fn source ->
      [start_dt, end_dt] = create_datetime(datetime, source.time)

      %{
        xmltv_id: source.xmltv_id,
        start_dt: start_dt,
        end_dt: end_dt
      }
    end)
  end

  # Create a daytime
  defp create_datetime(dt, range) do
    [start_time, end_time] = range |> String.split("-")

    # Start
    [start_hour, start_minute] =
      Regex.run(~r/^(\d\d)(\d\d)$/, start_time, capture: :all_but_first)

    start_dt =
      dt
      |> Timex.set(
        hour: start_hour |> String.to_integer(),
        minute: start_minute |> String.to_integer(),
        second: 00
      )
      |> Timex.shift(seconds: -1)

    # End
    [end_hour, end_minute] = Regex.run(~r/^(\d\d)(\d\d)$/, end_time, capture: :all_but_first)

    end_dt =
      dt
      |> Timex.set(
        hour: end_hour |> String.to_integer(),
        minute: end_minute |> String.to_integer(),
        second: 00
      )
      |> Timex.shift(seconds: 1)

    [start_dt, end_dt]
  end

  # Return a better format
  defp dayweek_to_string(1), do: "mo"
  defp dayweek_to_string(2), do: "tu"
  defp dayweek_to_string(3), do: "we"
  defp dayweek_to_string(4), do: "th"
  defp dayweek_to_string(5), do: "fr"
  defp dayweek_to_string(6), do: "sa"
  defp dayweek_to_string(7), do: "su"
end
