defmodule Main.TeamController do
  use Main, :controller
  alias Database.Translation
  alias Database.Translation.Team
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Translation.teams()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(t in Team,
        order_by: t.type
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "Team Translations"
    )
  end

  def new(conn, %{"team" => rule_params}) do
    rule_params
    |> Database.Translation.create_team()
    |> case do
      {:ok, rule} ->
        conn
        |> put_flash(:ok, "Translation added successfully.")
        |> redirect(to: "/team")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end

    changeset = Team.changeset(%Team{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Team.changeset(%Team{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id, "team" => rule_params} = _params) do
    rule = Database.Repo.get(Team, id)

    case Translation.update_team(rule, rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Translation updated successfully.")
        # Routes.rule_path(conn, :show, area)
        |> redirect(to: "/team")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", rule: rule, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(Team, id)

    changeset = Team.changeset(rule, %{})
    render(conn, "edit.html", rule: rule, changeset: changeset)
  end

  def delete(conn, %{"id" => id}) do
    Team
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Team removed successfully")
        |> redirect(to: "/team")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Team couldn't be removed")
        |> redirect(to: "/team")
    end
  end
end
