defmodule Main.BatchController do
  use Main, :controller
  alias Database.Repo
  alias Database.Importer.Batch
  import Ecto.Query, only: [from: 2]

  use Filterable.Phoenix.Controller

  filterable(Main.Filters.Batch)

  def index(conn, params) do
    {:ok, query, filter_values} = apply_filters(Batch, conn)

    scrivener = query |> Repo.paginate(params)

    render(conn, "index.html",
      page_title: "Batches",
      batches: Map.get(scrivener, :entries) |> Repo.preload(:channel),
      meta: filter_values,
      scrivener: scrivener
    )
  end

  def show(conn, %{"id" => id} = _params) do
    batch = Database.Repo.get(Batch, id)

    render(conn, "show.html", batch: batch)
  end
end
