defmodule Main.AugmenterRuleController do
  use Main, :controller
  alias Database.Importer
  alias Database.Importer.AugmenterRule
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Importer.augmenter_rules()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(er in AugmenterRule,
        preload: :channel
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "Augmenter Rules"
    )
  end

  def new(conn, %{"augmenter_rule" => rule_params}) do
    rule_params
    |> Database.Importer.create_augmenter_rule()
    |> case do
      {:ok, _rule} ->
        conn
        |> put_flash(:ok, "Rule added successfully.")
        |> redirect(to: "/augmenter_rule")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end

    changeset = AugmenterRule.changeset(%AugmenterRule{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = AugmenterRule.changeset(%AugmenterRule{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def edit(conn, %{"id" => id, "augmenter_rule" => rule_params} = _params) do
    rule = Database.Repo.get(AugmenterRule, id)

    case Importer.update_augmenter_rule(rule, rule_params) do
      {:ok, _rule} ->
        conn
        |> put_flash(:info, "Rule updated successfully.")
        # Routes.rule_path(conn, :show, area)
        |> redirect(to: "/augmenter_rule")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", rule: rule, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(AugmenterRule, id)

    changeset = AugmenterRule.changeset(rule, %{})
    render(conn, "edit.html", rule: rule, changeset: changeset)
  end

  def delete(conn, %{"id" => id}) do
    AugmenterRule
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Rule removed successfully")
        |> redirect(to: "/augmenter_rule")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Rule couldn't be removed")
        |> redirect(to: "/augmenter_rule")
    end
  end
end
