defmodule Importer.Helpers.Sport do
  @moduledoc """
  A helper for sport events
  """

  alias Database.Translation, as: DBTranslation


  @doc """
  Translates a sports type
  """
  def translate_type(type, value) do
    data =
      Importer.Helpers.Translation.translate_category(
        type,
        value
      )
      |> case do
        nil ->
          []

        data ->
          data
          |> Enum.map(& &1.category)
          |> Enum.reject(&is_nil/1)
          |> List.flatten()
          |> Enum.reject(&is_nil/1)
      end

    if length(data) > 0 do
      data
      |> List.first()
    else
      nil
    end
  end

  @doc """
  If one of these types, split the teams!
  """
  @sport_types [
    "soccer",
    "american football",
    "hockey",
    "bandy",
    "esports"
  ]
  def split_teams?(nil), do: false
  def split_teams?(""), do: false
  def split_teams?(type), do: @sport_types |> Enum.member?(type |> String.downcase())

  @doc """
  Translates a league
  """
  def translate_league(_type, nil, _string), do: nil
  def translate_league(_type, "", _string), do: nil
  def translate_league(_type, _sports_type, nil), do: nil
  def translate_league(_type, _sports_type, ""), do: nil

  def translate_league(type, sports_type, list) when is_list(list),
    do: Enum.map(list, &translate_league(type, sports_type |> String.downcase(), &1))

  def translate_league(type, sports_type, string) do
    case DBTranslation.get_league_by_string!(
           type |> String.downcase(),
           sports_type |> String.downcase(),
           string
         ) do
      nil ->
        {:ok, league} =
          DBTranslation.create_league(
            type |> String.downcase(),
            sports_type |> String.downcase(),
            string
          )

        league

      league ->
        league
    end
  end

  def map_league(nil), do: nil
  def map_league(""), do: nil
  def map_league(%Database.Translation.League{real_name: nil}), do: nil
  def map_league(%Database.Translation.League{real_name: ""}), do: nil

  def map_league(%Database.Translation.League{} = league) do
    %{
      name: league.real_name,
      type: league.sports_type
    }
  end

  @doc """
  Translates a team
  """
  def translate_team(_type, nil, _string), do: nil
  def translate_team(_type, "", _string), do: nil
  def translate_team(_type, _sports_type, nil), do: nil
  def translate_team(_type, _sports_type, ""), do: nil

  def translate_team(type, sports_type, list) when is_list(list),
    do: Enum.map(list, &translate_team(type, sports_type, &1))

  def translate_team(type, sports_type, string) do
    case DBTranslation.get_team_by_string!(
           type,
           sports_type,
           string
         ) do
      nil ->
        {:ok, team} =
          DBTranslation.create_team(
            type |> String.downcase(),
            sports_type |> String.downcase(),
            string
          )

        team

      team ->
        team
    end
  end

  def map_team(nil), do: nil
  def map_team(""), do: nil
  def map_team(%Database.Translation.Team{name: nil}), do: nil
  def map_team(%Database.Translation.Team{name: ""}), do: nil

  def map_team(%Database.Translation.Team{} = team) do
    %{
      name: team.name,
      type: team.sports_type
    }
  end
end
