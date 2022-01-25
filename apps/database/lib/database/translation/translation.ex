defmodule Database.Translation do
  @moduledoc """
  The User context.
  """

  # require Durango
  alias Database.Repo
  alias Database.Translation.{Category, Country, League, Team}

  # Module-wide string formatter
  defp format_string(string) do
    string
    |> String.trim()
    |> String.downcase()
  end

  @doc """
  Gets a single category.

  Returns `nil` if the Category does not exist.

  ## Examples

      iex> get_category!(123)
      %Category{}

      iex> get_category!(456)
      nil

  """
  def get_category!(id), do: Repo.get(Category, id)

  def get_category_by_string!(_type, nil), do: nil

  def get_category_by_string!(type, string) do
    string = format_string(string)

    Database.Repo.get_by(Category, type: format_string(type), original: string)
  end

  @doc """
  Creates a category.

  ## Examples

      iex> create_category("svt", "Action")
      {:ok, %Category{}}

      iex> create_category(nil, nil)
      {:error, %Durango.Changeset{}}

  """
  def create_category(_type, nil), do: nil

  def create_category(type, string) do
    string = format_string(string)

    %Category{}
    |> Category.changeset(%{type: format_string(type), original: string})
    |> Repo.insert()
  end

  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single league.

  Returns `nil` if the league does not exist.

  ## Examples

      iex> get_league!(123)
      %League{}

      iex> get_league!(456)
      nil

  """
  def get_league!(id), do: Repo.get(Category, id)

  def get_league_by_string!(_type, _sports_type, nil), do: nil
  def get_league_by_string!(_type, nil, _string), do: nil

  def get_league_by_string!(type, sports_type, string) do
    string = format_string(string)

    Database.Repo.get_by(League, type: format_string(type), sports_type: format_string(sports_type), original: string)
  end

  @doc """
  Creates a league.

  ## Examples

      iex> create_league("svt", "soccer", "Allsvenskan")
      {:ok, %League{}}

      iex> create_league(nil, nil, nil)
      {:error, %Durango.Changeset{}}

  """
  def create_league(_type, _sports_type, nil), do: nil
  def create_league(_type, nil, _string), do: nil

  def create_league(type, sports_type, string) do
    string = format_string(string)

    %League{}
    |> League.changeset(%{type: format_string(type), sports_type: format_string(sports_type), original: string})
    |> Repo.insert()
  end

  def create_league(attrs \\ %{}) do
    %League{}
    |> League.changeset(attrs)
    |> Repo.insert()
  end

  def update_league(%League{} = league, attrs) do
    league
    |> League.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single team.

  Returns `nil` if the team does not exist.

  ## Examples

      iex> get_team!(123)
      %Team{}

      iex> get_team!(456)
      nil

  """
  def get_team!(id), do: Repo.get(Category, id)

  def get_team_by_string!(_type, _sports_type, nil), do: nil
  def get_team_by_string!(_type, nil, _string), do: nil

  def get_team_by_string!(type, sports_type, string) do
    string = format_string(string)

    Database.Repo.get_by(Team, type: format_string(type), sports_type: format_string(sports_type), original: string)
  end

  @doc """
  Creates a team.

  ## Examples

      iex> create_team("svt", "soccer", "AIK")
      {:ok, %Team{}}

      iex> create_team(nil, nil, nil)
      {:error, %Durango.Changeset{}}

  """
  def create_team(_type, _sports_type, nil), do: nil
  def create_team(_type, nil, _string), do: nil

  def create_team(type, sports_type, string) do
    string = format_string(string)

    %Team{}
    |> Team.changeset(%{type: format_string(type), sports_type: format_string(sports_type), original: string})
    |> Repo.insert()
  end

  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single league.

  Returns `nil` if the league does not exist.

  ## Examples

      iex> get_league!(123)
      %League{}

      iex> get_league!(456)
      nil

  """
  def get_country!(id), do: Repo.get(Country, id)

  def get_country_by_string!(_type, nil), do: nil

  def get_country_by_string!(type, string) do
    string = format_string(string)

    Database.Repo.get_by(Country, type: format_string(type), original: string)
  end

  @doc """
  Creates a country.

  ## Examples

      iex> create_country("svt", "Sverige")
      {:ok, %Country{}}

      iex> create_country(nil, nil)
      {:error, %Durango.Changeset{}}

  """
  def create_country(_type, nil), do: nil

  def create_country(type, string) do
    string = format_string(string)

    %Country{}
    |> Country.changeset(%{type: type, original: string})
    |> Repo.insert()
  end

  def create_country(attrs \\ %{}) do
    %Country{}
    |> Country.changeset(attrs)
    |> Repo.insert()
  end

  def update_country(%Country{} = country, attrs) do
    country
    |> Country.changeset(attrs)
    |> Repo.update()
  end
end
