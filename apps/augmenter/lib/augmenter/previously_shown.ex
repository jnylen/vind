# TODO: Create.

# This Augmenter will look through our database and add previously shown tags to the channels that have reruns.
defmodule Augmenter.PreviouslyShown do
  @moduledoc """
  Basic fixups of faulty data. Such as wrong title etc.
  """
  use Augmenter.Base

  @doc """
  Find a previously shown airing and sets it as the rerun.
  """
  @impl true
  def filter(airing, %{matchby: "set_previously_shown"}) do
    cond do
      # Ignore these
      Enum.member?(airing.qualifiers, "live") ->
        %{}

      !airing.previously_shown ->
        %{}

      # Is a movie?
      airing.program_type == "movie" ->
        airing |> match(:movie)

      # Is a show (with S01 and E01)
      airing.program_type == "series" &&
        !is_nil(airing.episode) && !is_nil(airing.season) ->
        airing |> match(:tv)

      # No match
      true ->
        %{}
    end
  end

  # Match a movie
  defp match(airing, :movie) do
    %{}
  end

  # Match a tv show
  defp match(airing, :tv) do
    %{}
  end

  defp match(_, _), do: %{}

  # No match
  @impl true
  def filter(_airing, _rules), do: {:ok, %{}}
end
