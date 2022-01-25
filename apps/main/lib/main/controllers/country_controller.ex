defmodule Main.CountryController do
  use Main, :controller
  alias Database.Translation
  alias Database.Translation.Country
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Translation.countries()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(c in Country,
        order_by: c.type
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "Country Translations"
    )
  end

  def new(conn, %{"country" => rule_params}) do
    rule_params
    |> Database.Translation.create_country()
    |> case do
      {:ok, rule} ->
        conn
        |> put_flash(:ok, "Translation added successfully.")
        |> redirect(to: "/country")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end

    changeset = Country.changeset(%Country{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Country.changeset(%Country{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id, "country" => rule_params} = _params) do
    rule = Database.Repo.get(Country, id)

    case Translation.update_country(rule, rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Translation updated successfully.")
        # Routes.rule_path(conn, :show, area)
        |> redirect(to: "/country")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", rule: rule, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(Country, id)

    changeset = Country.changeset(rule, %{})
    render(conn, "edit.html", rule: rule, changeset: changeset)
  end

  def delete(conn, %{"id" => id}) do
    Country
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Country removed successfully")
        |> redirect(to: "/country")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Country couldn't be removed")
        |> redirect(to: "/country")
    end
  end
end
