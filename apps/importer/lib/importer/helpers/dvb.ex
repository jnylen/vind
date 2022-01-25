defmodule Importer.Helpers.DVB do
  @moduledoc """
  A helper module for parsing DVB Nibbles into genres.
  """

  # List: https://www.etsi.org/deliver/etsi_en/300400_300499/300468/01.11.01_60/en_300468v011101p.pdf

  # Main program types
  @nibbles_main %{
    # UNDEF
    0 => nil,
    # MOVIE
    1 => "movie",
    # NEWS
    2 => "series",
    # SHOW/GAMESHOW
    3 => "series",
    # SPORTS
    4 => "sports",
    # CHILDREN'S
    5 => "series",
    # MUSIC
    6 => "series",
    # ARTS / CULTURE
    7 => "series",
    # SOCIAL / POLITICS / ECONOMICS
    8 => "series",
    # EDUCATION
    9 => "series",
    # LEISURE HOBBIES
    10 => "series",
    # SPECIALS
    11 => "series"
  }

  @doc """
  Tries to convert a nibble integer to a normal category
  """
  def parse_type(nil), do: nil
  def parse_type(""), do: nil

  def parse_type(nibble) when is_integer(nibble) do
    @nibbles_main
    |> Map.get(nibble)
  end
end
