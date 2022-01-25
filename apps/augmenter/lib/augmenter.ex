defmodule Augmenter do
  @moduledoc """
  Documentation for Augmenter.
  """

  alias Database.Importer.Batch
  alias Database.Importer, as: DataImporter
  alias Database.Network

  @doc """
  Augment a batch
  """
  def augment(nil), do: nil

  def augment(%Batch{} = batch) do
    require Logger
    # Grab all augmenter rules
    augmenter_rules = DataImporter.get_all_augmenter_rules()

    channel = batch.channel_id |> Network.get_channel!()

    # Score them on the possibility of augmentation
    results =
      for airing <- Network.get_airings_by_batch_id!(batch) do
        # Get valid augmenter rules for this programme
        rules =
          augmenter_rules
          |> valid_augmenter_rules(airing)
          |> Enum.filter(fn el -> el.score != nil end)
          |> Enum.sort_by(fn r -> r.score end)

        # Run through the rules
        for rule <- rules do
          # Logger.info("Augmenter #{rule.augmenter}: Running for #{airing.id}")

          case apply(String.to_existing_atom("Elixir.Augmenter.#{rule.augmenter}"), :process, [
                 airing,
                 rule
               ]) do
            {:ok, map} when map_size(map) == 0 ->
              {:ok, "nothing to update"}

            {:ok, new_airing} ->
              Logger.info(
                "Augmenter #{rule.augmenter}: Updated airing (#{airing.id}) with #{
                  inspect(new_airing)
                }"
              )

              db_new_airing =
                Network.update_airing(
                  airing,
                  new_airing
                )

              {:ok, db_new_airing}

            {:error, error} ->
              {:error, error}

            message ->
              {:error, message}
          end
        end
      end

    # Only run if there were any changes
    if !Enum.empty?(List.flatten(results)) do
      Worker.Exporter.enqueue(%{"channel" => channel.xmltv_id})
    end

    # Return the results of all augmenters that have been run
    {:ok, List.flatten(results)}
  end

  # Run through the augmenter rules and ignore rules that doesn't have nil or
  # the same channel_id.
  defp valid_augmenter_rules(nil, _airing), do: []
  defp valid_augmenter_rules([], _airing), do: []

  defp valid_augmenter_rules([rule | rules], %{channel_id: channel_id} = airing) do
    case rule do
      %{channel_id: nil} ->
        [validate_augmenter_rule(rule, airing) | valid_augmenter_rules(rules, airing)]

      %{channel_id: ^channel_id} ->
        [validate_augmenter_rule(rule, airing) | valid_augmenter_rules(rules, airing)]

      _ ->
        valid_augmenter_rules(rules, airing)
    end
  end

  # Validate the augmenter rule and add a score.
  defp validate_augmenter_rule(rule, airing) do
    new_rule = Map.from_struct(rule)

    # Start score at 0
    0
    |> score("episodeabs", airing, rule)
    |> score("channel", airing, rule)
    |> score("title", airing, rule)
    |> set_score(new_rule)

    # Otherfield scoring
    # TODO: Fix other field matching.
  end

  defp set_score(score, new_rule), do: Map.put_new(new_rule, :score, score)

  # Scoring
  defp score(nil, _, _, _), do: nil

  defp score(score, "episodeabs", _, %{remoteref: nil, matchby: "episodeabs"}), do: score - 2

  defp score(score, "channel", %{channel_id: channel_id}, %{channel_id: channel_id}),
    do: score + 1

  defp score(score, "title", airing, rule) do
    first_title = List.first(airing.titles).value

    case rule do
      # Match all
      %{title: nil} ->
        score

      # Title straight match?
      %{title: ^first_title} ->
        score + 4

      # Regex matching as titles are returned as regexps
      %{title: title, title_language: title_lang} ->
        title
        |> case do
          %Regex{} ->
            if match_regex(title, airing.titles, title_lang) do
              score + 4
            else
              # If the titles doesn't match then it shouldnt be run.
              nil
            end

          val ->
            if match_title(title, airing.titles, title_lang) do
              score + 4
            else
              # If the titles doesn't match then it shouldnt be run.
              nil
            end
        end
    end
  end

  # Just return score if no match
  defp score(score, _, _, _), do: score

  # Lowercase trim
  defp lc_trim(string), do: String.downcase(String.trim(string))

  # Match titles
  defp match_title(_match_parameter, [], nil), do: false
  defp match_title(_match_parameter, [], _lang), do: false

  defp match_title(match_parameter, [value | values], nil) do
    case lc_trim(match_parameter) == lc_trim(value.value) do
      true -> true
      false -> match_title(match_parameter, values, nil)
    end
  end

  defp match_title(match_parameter, [value | values], language) do
    case language == value.language && lc_trim(match_parameter) == lc_trim(value.value) do
      true -> true
      false -> match_title(match_parameter, values, language)
    end
  end

  # Check if a value is matched with that specific language, otherwise false
  defp match_regex(%Regex{}, [], _lang), do: false

  defp match_regex(%Regex{} = regex, [value | values], nil) do
    case Regex.match?(regex, value.value) do
      true -> true
      false -> match_regex(regex, values, nil)
    end
  end

  defp match_regex(%Regex{} = regex, [value | values], value_lang) do
    case value.language == value_lang && Regex.match?(regex, value.value) do
      true -> true
      false -> match_regex(regex, values, value_lang)
    end
  end
end
