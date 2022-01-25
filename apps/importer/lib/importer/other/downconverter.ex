defmodule Importer.Other.Downconverter do
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
      |> Database.Repo.preload(:source_channel)
      |> Map.get(:source_channel)
      |> get_airings(date |> Date.from_iso8601!() |> Timex.to_datetime(:utc))
      |> Enum.map(&flags(&1, channel.flags))

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

  defp get_airings(source_channel, datetime) do
    import Ecto.Query, only: [from: 2]

    if is_nil(source_channel) do
      []
    else
      max_datetime =
        datetime
        |> Timex.shift(days: 1)

      from(a in Network.Airing,
        where: a.channel_id == ^source_channel.id,
        where: a.start_time >= ^datetime,
        where: a.start_time < ^max_datetime,
        order_by: a.start_time,
        preload: [:image_files]
      )
      |> Repo.all()
      |> Enum.map(&DBHelper.clean_up_airing/1)
    end
  end

  # Map over flags
  defp flags(a, flags) do
    flags
    |> Enum.map_reduce(a, fn flag, airing ->
      {[flag], flag(airing, String.to_existing_atom(flag.function), flag)}
    end)
    |> into_map()
  end

  defp into_map({_, map}), do: map

  # Flags (delete)
  defp flag(airing, :delete, %{type: "qualifiers", value: value}),
    do: airing |> Map.put(:qualifiers, airing.qualifiers |> delete_from_list(value))

  # Flags (add)
  defp flag(airing, :add, %{type: "qualifiers", value: value}),
    do: airing |> Map.put(:qualifiers, airing.qualifiers |> add_to_list(value))

  # No match?
  defp flag(airing, _, _), do: airing

  # Add to list
  defp add_to_list(list, element), do: list |> Enum.concat([element]) |> Enum.uniq()
  defp delete_from_list(list, element), do: list |> List.delete(element) |> Enum.uniq()
end
