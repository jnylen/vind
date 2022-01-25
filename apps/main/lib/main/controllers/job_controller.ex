defmodule Main.JobController do
  use Main, :controller
  alias Database.Importer.Job
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    {:ok, filter} =
      Database.Filters.Importer.jobs()
      |> Filtrex.parse_params(params |> Map.drop(["page"]))

    jobs =
      from(j in Job,
        order_by: j.type
      )
      |> Filtrex.query(filter)
      |> Database.Repo.paginate(params)

    render(conn, "index.html",
      jobs: jobs,
      page_title: "Jobs"
    )
  end
end
