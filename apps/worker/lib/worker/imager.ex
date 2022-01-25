defmodule Worker.Imager do
  @moduledoc """
  Handles images
  """

  use TaskBunny.Job

  @impl true
  def timeout, do: 1_200_000

  @impl true
  def queue_key(%{"airing_id" => airing_id, "image" => %{"source" => source}}) do
    "image_#{airing_id}_#{source}"
  end

  @impl true
  def execution_key(%{"airing_id" => airing_id}) do
    "image_#{airing_id}"
  end

  @impl true
  def execution_key(_), do: nil

  @impl true
  def perform(%{"airing_id" => airing_id, "image" => %{"source" => source}} = params) do
    require Logger

    airing = Database.Repo.get(Database.Network.Airing, airing_id)

    if airing do
      airing = Database.Repo.preload(airing, [:channel, :image_files])

      Logger.info(
        "[imager] [#{airing.channel.xmltv_id}] [#{airing.start_time}] Running #{source}"
      )

      image =
        Map.get(params, "image")
        |> struct_from_map(as: %ImageManager.Image{})
        |> ImageManager.add_or_get_file?()

      if image do
        airing
        |> Database.Network.Airing.changeset()
        |> Ecto.Changeset.put_assoc(
          :image_files,
          Enum.concat(airing.image_files, [image])
        )
        |> Database.Repo.update()
      end

      if Application.get_env(:main, :environment) == :prod do
        Worker.Exporter.enqueue(%{"channel" => airing.channel.xmltv_id})
      end

      Logger.info("[imager] [#{airing.channel.xmltv_id}] [#{airing.start_time}] Done")
    else
    end

    :ok
  end

  def enqueue_many(list, airing_id) when is_list(list) do
    list
    |> Enum.map(&enqueue(%{"airing_id" => airing_id, "image" => &1}))
  end

  def struct_from_map(a_map, as: a_struct) do
    # Find the keys within the map
    keys =
      Map.keys(a_struct)
      # Process map, checking for both string / atom keys
      |> Enum.filter(fn x -> x != :__struct__ end)

    processed_map =
      for key <- keys, into: %{} do
        value = Map.get(a_map, key) || Map.get(a_map, to_string(key))
        {key, value}
      end

    Map.merge(a_struct, processed_map)
  end
end
