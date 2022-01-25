defmodule Main.CategoryController do
  use Main, :controller
  alias Database.Translation
  alias Database.Translation.Category
  alias Database.Repo
  import Ecto.Query, only: [from: 2]

  use Filterable.Phoenix.Controller

  filterable(Main.Filters.Category)

  def index(conn, params) do
    {:ok, query, filter_values} = apply_filters(Category, conn)

    scrivener = query |> Repo.paginate(params)

    render(conn, "index.html",
      page_title: "Categories",
      rules: Map.get(scrivener, :entries),
      meta: filter_values,
      scrivener: scrivener
    )
  end

  def new(conn, %{"category" => category_params}) do
    category_params
    |> Database.Translation.create_category()
    |> case do
      {:ok, category} ->
        conn
        |> put_flash(:ok, "Translation added successfully.")
        |> redirect(to: "/category")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end

    changeset = Category.changeset(%Category{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Category.changeset(%Category{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id, "category" => category_params} = _params) do
    rule = Database.Repo.get(Category, id)

    category_params = Map.put_new(category_params, "category", nil)

    case Translation.update_category(rule, category_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Translation updated successfully.")
        # Routes.category_path(conn, :show, area)
        |> redirect(to: "/category")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", rule: rule, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(Category, id)

    changeset = Category.changeset(rule, %{})
    render(conn, "edit.html", rule: rule, changeset: changeset)
  end

  def delete(conn, %{"id" => id}) do
    Category
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Category removed successfully")
        |> redirect(to: "/category")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Category couldn't be removed")
        |> redirect(to: "/category")
    end
  end
end
