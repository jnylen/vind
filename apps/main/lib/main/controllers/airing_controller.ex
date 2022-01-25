defmodule Main.AiringController do
  use Main, :controller
  alias Database.Repo
  alias Database.Network.Airing
  import Ecto.Query, only: [from: 2]

  use Filterable.Phoenix.Controller

  filterable(Main.Filters.Airing)

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    {:ok, query, filter_values} = apply_filters(Airing, conn)

    scrivener = query |> Repo.paginate(params)

    render(conn, "index.html",
      page_title: "Airings",
      airings: Map.get(scrivener, :entries) |> Repo.preload(:channel),
      meta: filter_values,
      scrivener: scrivener
    )
  end

  def show(conn, %{"id" => id}) do
    airing =
      Airing
      |> Repo.get(id)
      |> Repo.preload([:channel, :image_files, :batch])

    render(
      conn,
      "show.html",
      airing: airing
    )
  end
end
