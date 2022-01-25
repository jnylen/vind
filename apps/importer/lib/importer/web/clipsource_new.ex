defmodule Importer.Web.ClipsourceNew do
  @moduledoc """
  Importer for Clipsource
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Sport, as: SportHelper
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation
  alias Importer.Parser.PublicSchedule, as: Parser

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body}) do
    body
    |> process(channel)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("UTC"),
      channel
    )
  end

  defp process_items({:ok, []}, tuple, _), do: tuple

  defp process_items({:ok, [item | items]}, tuple, channel) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> parse_airing(channel)
        |> Parser.remove_custom_fields()
      ),
      channel
    )
  end

  defp process(body, channel) do
    body
    |> Parser.parse(channel)
  end

  # Parse nent sport
  defp parse_airing(%{"n_category" => "sport"} = airing, channel),
    do: parse_nent_airing(airing, channel)

  defp parse_airing(%{"n_category" => "sport-series"} = airing, channel),
    do: parse_nent_airing(airing, channel)

  defp parse_airing(airing, channel) do
    # Get titles
    titles = parse_titles(:title, Map.get(airing, :titles, []))
    subtitles = parse_titles(:subtitle, Map.get(airing, :titles, []))

    # Get directors (movie check)
    directors = parse_credits("director", Map.get(airing, :credits, []))

    backup_title = if(Enum.empty?(titles), do: subtitles, else: titles)

    # Do a check if its a movie by conditions
    movie_check =
      cond do
        Enum.count(directors) > 0 && is_nil(Map.get(airing, :episode)) ->
          true

        Enum.member?(Map.get(airing, "c_treenodes", []), "Film") ->
          true

        true ->
          false
      end

    airing
    |> Map.put(:titles, if(movie_check, do: subtitles, else: backup_title))
    |> Map.put(
      :subtitles,
      if(movie_check || Enum.empty?(titles),
        do: [],
        else: remove_non_subtitles(titles, subtitles)
      )
    )
    |> set_movie_type(movie_check)
    |> append_categories(
      Translation.translate_category(
        "Clipsource",
        Map.get(airing, "main_genres", []) |> List.flatten()
      )
    )
    |> append_categories(
      Translation.translate_category(
        "Clipsource",
        Map.get(airing, "sub_genres", []) |> List.flatten()
      )
    )
  end

  # NENT parsing
  defp parse_nent_airing(airing, _channel) do
    sports_genre =
      SportHelper.translate_type(
        "nent_sport",
        Map.get(airing, "sub_genres", [])
      )

    league =
      SportHelper.map_league(
        SportHelper.translate_league(
          "nent",
          sports_genre,
          airing.titles
          |> Enum.find(fn title -> title.type == "original" end)
          |> maybe_get(:value)
        )
      )

    # TODO: Parse teams from descriptions too. They seem to mix em..
    teams =
      if not is_nil(league) && SportHelper.split_teams?(sports_genre) do
        airing.titles
        |> Enum.find(fn title -> title.type == "content" end)
        |> maybe_get(:value)
        |> cleanup_team_string
        |> Text.split(~r/( - |-| og )/)
        |> Okay.map(fn team ->
          SportHelper.map_team(SportHelper.translate_team("nent", sports_genre, team))
        end)
      else
        []
      end

    %{
      start_time: Map.get(airing, :start_time),
      program_type: "sports_event",
      titles: parse_titles(:title, Map.get(airing, :titles, [])),
      subtitles: parse_titles(:subtitle, Map.get(airing, :titles, [])),
      descriptions: Map.get(airing, :descriptions, []),
      qualifiers: Map.get(airing, :qualifiers, []),
      sport: %{
        event: league,
        teams: Enum.filter(teams, &(!is_nil(&1))),
        play_date: calculate_play_date(airing, league),
        game: nil
      },
      production_date: Map.get(airing, :production_year),
      images: Map.get(airing, :images, [])
    }
    |> append_categories(
      Translation.translate_category(
        "nent_sport",
        Map.get(airing, "sub_genres", [])
      )
    )
  end

  defp set_movie_type(airing, false), do: airing
  defp set_movie_type(airing, true), do: airing |> Map.put(:program_type, "movie")

  # Returns play date based on if its live or not
  defp calculate_play_date(%{qualifiers: ["live"], start_time: start_time}, _), do: start_time
  defp calculate_play_date(_, _), do: nil

  defp cleanup_team_string(nil), do: nil
  defp cleanup_team_string(""), do: nil

  defp cleanup_team_string(string) do
    string
    # |> String.replace("opfølgning på kampen mellem", "")
    # |> String.replace("optakt til", "")
  end

  defp maybe_get(nil, _), do: nil

  defp maybe_get(map, value) do
    Map.get(map, value) || nil
  end

  # Return true if this is the type
  defp is_type([map], type), do: map.original_type == type
  defp is_type(map, type) when is_map(map), do: map.original_type == type

  # Parse credits for specific types
  defp parse_credits(type, [%{type: type} = director | credits]) do
    [director] ++ parse_credits(type, credits)
  end

  defp parse_credits(type, [_ | credits]), do: parse_credits(type, credits)
  defp parse_credits(_, []), do: []

  # Clipsource mixes subtitles and normal titles..
  defp parse_titles(_, nil), do: []
  defp parse_titles(_, []), do: []

  defp parse_titles(:title, titles) do
    titles
    |> Okay.reject(&is_nil(&1.value))
    |> Enum.filter(&is_type(&1, "series"))
    |> Okay.reject(&is_nil(&1.value))
    |> List.flatten()
  end

  defp parse_titles(:subtitle, titles) do
    titles
    |> Okay.reject(&is_nil(&1.value))
    |> Enum.filter(&is_type(&1, "content"))
    |> Okay.reject(&is_nil(&1.value))
    |> List.flatten()
  end

  # Remove titles that have ended up in subtitles
  defp remove_non_subtitles(titles, subtitles) do
    tits = Okay.map(titles, & &1.value)

    subtitles
    |> Okay.reject(&Enum.member?(tits, &1.value))
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    sprintf("%s?key=%s&date=%s&channelId=%s", [
      config.url_root,
      config.api_key,
      date |> to_string(),
      channel.grabber_info
    ])
  end
end
