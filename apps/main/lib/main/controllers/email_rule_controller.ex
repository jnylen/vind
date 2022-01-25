defmodule Main.EmailRuleController do
  use Main, :controller
  alias Database.Importer
  alias Database.Importer.EmailRule
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Importer.email_rules()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(er in EmailRule,
        preload: :channels
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "Email Rules"
    )
  end

  def new(conn, %{"email_rule" => rule_params}) do
    Main.Forms.EmailRuleForm
    |> create_form(%Database.Importer.EmailRule{}, rule_params)
    |> insert_form_data
    |> case do
      {:ok, _rule} ->
        # do something with a new article struct
        conn
        |> put_flash(:ok, "Rule added successfully.")
        |> redirect(to: "/email_rule")

      {:error, form} ->
        render(conn, "new.html", form: form)
    end
  end

  def new(conn, _params) do
    form = create_form(Main.Forms.EmailRuleForm, %Database.Importer.EmailRule{})

    render(conn, "new.html", form: form)
  end

  def edit(conn, %{"id" => id, "email_rule" => rule_params} = _params) do
    rule = Database.Repo.get(EmailRule, id)

    Main.Forms.EmailRuleForm
    |> create_form(rule, rule_params)
    |> update_form_data
    |> case do
      {:ok, _rule} ->
        # do something with a new article struct
        conn
        |> put_flash(:ok, "Rule updated successfully.")
        |> redirect(to: "/email_rule")

      {:error, form} ->
        render(conn, "edit.html", rule: rule, form: form)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(EmailRule, id)
    form = create_form(Main.Forms.EmailRuleForm, rule)

    render(conn, "edit.html", rule: rule, form: form)
  end

  def delete(conn, %{"id" => id}) do
    EmailRule
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Rule removed successfully")
        |> redirect(to: "/email_rule")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Rule couldn't be removed")
        |> redirect(to: "/email_rule")
    end
  end
end
