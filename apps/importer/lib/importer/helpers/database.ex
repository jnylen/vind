defmodule Importer.Helpers.Database do
  @moduledoc """
  A helper to clean up data received from the database.
  """

  @doc """
  We need to delete a few keys as they shouldn't be moved over
  """
  # TODO: clean_up_embed for sport
  def clean_up_airing(airing) when is_map(airing) do
    airing
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.delete(:id)
    |> Map.delete(:channel)
    |> Map.delete(:channel_id)
    |> Map.delete(:batch)
    |> Map.delete(:batch_id)
    |> Map.delete(:inserted_at)
    |> Map.delete(:updated_at)
    |> Map.delete(:previously_shown)
    |> Map.delete(:sport)
    |> Map.put(:titles, clean_up_embed(airing.titles))
    |> Map.put(:subtitles, clean_up_embed(airing.subtitles))
    |> Map.put(:descriptions, clean_up_embed(airing.descriptions))
    |> Map.put(:blines, clean_up_embed(airing.blines))
    |> Map.put(:credits, clean_up_embed(airing.credits))
    |> Map.put(:metadata, clean_up_embed(airing.metadata))
    |> Map.put(:migrated_image_files, Map.get(airing, :image_files, []))
  end

  # Remove ids etc from embeds
  defp clean_up_embed(list) when is_list(list) do
    list
    |> Enum.map(&clean_up_embed/1)
  end

  defp clean_up_embed(map) when is_map(map) do
    map
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.delete(:id)
  end
end
