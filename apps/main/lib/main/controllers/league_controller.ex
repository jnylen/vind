defmodule Main.LeagueController do
  use Main, :controller
  alias Database.Translation
  alias Database.Translation.League
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Translation.leagues()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(l in League,
        order_by: l.type
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "League Translations"
    )
  end

  def new(conn, %{"league" => rule_params}) do
    rule_params
    |> Database.Translation.create_league()
    |> case do
      {:ok, rule} ->
        conn
        |> put_flash(:ok, "Translation added successfully.")
        |> redirect(to: "/league")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end

    changeset = League.changeset(%League{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = League.changeset(%League{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id, "league" => rule_params} = _params) do
    rule = Database.Repo.get(League, id)

    case Translation.update_league(rule, rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Translation updated successfully.")
        # Routes.rule_path(conn, :show, area)
        |> redirect(to: "/league")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", rule: rule, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(League, id)

    changeset = League.changeset(rule, %{})
    render(conn, "edit.html", rule: rule, changeset: changeset)
  end

  def delete(conn, %{"id" => id}) do
    League
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "League removed successfully")
        |> redirect(to: "/league")

      {:error, _error} ->
        conn
        |> put_flash(:error, "League couldn't be removed")
        |> redirect(to: "/league")
    end
  end
end
