defmodule Main.FtpRuleController do
  use Main, :controller
  alias Database.Importer
  alias Database.Importer.FtpRule
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Importer.ftp_rules()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    rules =
      from(er in FtpRule,
        preload: :channels
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      rules: rules,
      page_title: "Ftp Rules"
    )
  end

  def new(conn, %{"ftp_rule" => rule_params}) do
    Main.Forms.FtpRuleForm
    |> create_form(%Database.Importer.FtpRule{}, rule_params)
    |> insert_form_data
    |> case do
      {:ok, _rule} ->
        # do something with a new article struct
        conn
        |> put_flash(:ok, "Rule added successfully.")
        |> redirect(to: "/ftp_rule")

      {:error, form} ->
        render(conn, "new.html", form: form)
    end
  end

  def new(conn, _params) do
    form = create_form(Main.Forms.FtpRuleForm, %Database.Importer.FtpRule{})

    render(conn, "new.html", form: form)
  end

  def edit(conn, %{"id" => id, "ftp_rule" => rule_params} = _params) do
    rule = Database.Repo.get(FtpRule, id)

    Main.Forms.FtpRuleForm
    |> create_form(rule, rule_params)
    |> update_form_data
    |> case do
      {:ok, _rule} ->
        # do something with a new article struct
        conn
        |> put_flash(:ok, "Rule updated successfully.")
        |> redirect(to: "/ftp_rule")

      {:error, form} ->
        render(conn, "edit.html", rule: rule, form: form)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    rule = Database.Repo.get(FtpRule, id)
    form = create_form(Main.Forms.FtpRuleForm, rule)

    render(conn, "edit.html", rule: rule, form: form)
  end

  def delete(conn, %{"id" => id}) do
    FtpRule
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Rule removed successfully")
        |> redirect(to: "/ftp_rule")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Rule couldn't be removed")
        |> redirect(to: "/ftp_rule")
    end
  end
end
