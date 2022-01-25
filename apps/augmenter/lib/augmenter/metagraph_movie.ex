defmodule Augmenter.MetagraphMovie do
  @moduledoc """
  Metagraph augmenter for Movies
  """
  use Augmenter.Base

  alias Augmenter.Metagraph.Client

  @impl true
  def filter(%{program_type: "movie", metadata: metadata} = airing, rule) do
    if get_metadata("metagraph", metadata) do
      %{}
    else
      airing
      |> match(rule)
    end
  end

  def filter(airing, _rule), do: %{}

  @doc """
  Match by IMDB ID
  """
  def match(%{metadata: metadata} = airing, %{matchby: "imdb_id"}) do
    if imdb_id = get_metadata("imdb", metadata) do
      "media.imdb_id"
      |> Client.find(imdb_id)
      |> case do
        nil ->
          %{}

        metagraph_id ->
          item = Client.one(metagraph_id)

          %{}
          |> merge_with_data_from_metagraph(airing, Map.get(item, "attributes", []))
      end
    else
      %{}
    end
  end

  @doc """
  Match by title/label
  """
  def match(%{titles: titles, metadata: metadata} = airing, %{
        matchby: "title"
      }) do
    titles
    |> Enum.uniq_by(fn t -> Map.get(t, :value) end)
    |> Enum.reduce([], &map_by_titles/2)
    |> Enum.map(fn item -> score_the_result(item, airing) end)
    |> Enum.sort_by(fn v ->
      List.first(v)
    end)
    |> List.last()
    |> case do
      [0, _result] ->
        %{}

      [
        score,
        %{
          "attributes" => item
        }
      ] ->
        if score > 50 do
          %{}
          |> merge_with_data_from_metagraph(airing, item)
        else
          %{}
        end

      _ ->
        %{}
    end
  end

  defp map_by_titles(title, acc) do
    results =
      title
      |> Map.get(:value)
      |> Client.search("film")
      |> Enum.map(fn m -> Client.one(Map.get(m, "uid")) end)

    Enum.concat(acc, results)
  end

  # Return if no items are left
  defp merge_with_data_from_metagraph(new_airing, _airing, []), do: new_airing

  # Append metagraph id
  defp merge_with_data_from_metagraph(new_airing, airing, [%{"key" => "uid"} = v | vals]) do
    new_airing
    |> Map.put(
      :metadata,
      merge_values(
        [%{type: "metagraph", value: Map.get(v, "value")}],
        Map.get(airing, :metadata, [])
      )
    )
    |> merge_with_data_from_metagraph(airing, vals)
  end

  # Process next item
  defp merge_with_data_from_metagraph(new_airing, airing, [_val | vals]),
    do: merge_with_data_from_metagraph(new_airing, airing, vals)

  # Catch all
  defp merge_with_data_from_metagraph(new_airing, _airing, _), do: new_airing

  defp score_the_result(film, airing) do
    score =
      film
      |> Map.get("attributes", [])
      |> Enum.reduce(0, fn attr, acc ->
        acc + score!(attr, airing)
      end)

    [score, film]
  end

  defp score!(%{"key" => "label", "value" => mg_titles}, %{titles: airing_titles}) do
    mg_values =
      mg_titles
      |> Enum.map(fn t -> Map.get(t, "value") end)

    airing_values =
      airing_titles
      |> Enum.map(fn t -> Map.get(t, :value) end)

    mg_values
    |> match_strings(airing_values)
    |> case do
      true -> 50
      false -> 0
    end
  end

  defp score!(%{"key" => "crew", "value" => mg_crew}, %{credits: []}), do: 0
  defp score!(%{"key" => "crew", "value" => []}, %{credits: _}), do: 0

  defp score!(%{"key" => "crew", "value" => mg_crew}, %{credits: mg_credits}) do
    mg_credits
    |> Enum.filter(fn v ->
      Enum.member?(["director"], v.type)
    end)
    |> Enum.reduce(0, fn x, acc ->
      if match_crew!(x, mg_crew) do
        acc + 20
      else
        acc
      end
    end)
  end

  defp score!(%{"key" => "performances", "value" => mg_performances}, %{credits: []}), do: 0
  defp score!(%{"key" => "performances", "value" => []}, %{credits: _}), do: 0

  defp score!(%{"key" => "performances", "value" => mg_performances}, %{credits: mg_credits}) do
    mg_credits
    |> Enum.filter(fn v ->
      Enum.member?(["actor"], v.type)
    end)
    |> Enum.reduce(0, fn x, acc ->
      if match_performance!(x, mg_performances) do
        acc + 5
      else
        acc
      end
    end)
  end

  defp score!(%{"key" => "releases", "value" => mg_crew}, %{credits: mg_credits}) do
    # TODO

    0
  end

  defp score!(_, _), do: 0

  defp match_strings(values1, values2) do
    values1
    |> Enum.any?(fn v ->
      Enum.any?(values2, fn av ->
        Levenshtein.distance(v, av) < 4
      end)
    end)
  end

  defp match_crew!(crew, mg_crew) do
    mg_crew
    |> Enum.filter(fn v ->
      Enum.member?(["director"], Map.get(v, "job"))
    end)
    |> Enum.any?(fn v ->
      v
      |> Map.get("person", %{})
      |> Map.get("label", [])
      |> Enum.map(fn l ->
        Map.get(l, "value")
      end)
      |> Enum.uniq()
      |> match_strings([crew.person])
    end)
  end

  defp match_performance!(performance, mg_performances) do
    mg_performances
    |> Enum.map(fn v ->
      v
      |> Map.get("person", %{})
      |> Map.get("label", [])
      |> Enum.map(fn l ->
        Map.get(l, "value")
      end)
      |> Enum.uniq()
    end)
    |> List.flatten()
    |> match_strings([performance.person])
  end
end
