defmodule Main.FileController do
  use Main, :controller
  alias Database.Importer.File
  alias Database.Repo
  alias Database.Network.Channel
  alias Shared.File.Helper, as: FSHelper
  import Ecto.Query, only: [from: 2]

  use Filterable.Phoenix.Controller

  filterable(Main.Filters.File)

  def index(conn, params) do
    {:ok, query, filter_values} = apply_filters(File, conn)

    scrivener = query |> Repo.paginate(params)

    render(conn, "index.html",
      page_title: "Files",
      files: Map.get(scrivener, :entries) |> Repo.preload(:channel),
      meta: filter_values,
      scrivener: scrivener
    )
  end

  def show(conn, %{"id" => id} = _params) do
    file = Database.Repo.get(File, id)

    render(conn, "show.html", file: file)
  end

  def new(conn, %{"file" => %{"channel_id" => channel_id, "attachment" => attachment}}) do
    channel = Database.Repo.get(Channel, channel_id)
    checksum = FSHelper.file_checksum(attachment.path)

    %File{}
    |> File.changeset(%{
      channel_id: channel.id,
      file_name: attachment.filename,
      status: "new",
      checksum: checksum,
      source: "manual"
    })
    |> Database.Importer.upload_file(
      attachment.path,
      channel,
      "manual"
    )
    |> case do
      {:ok, _rule} ->
        # TODO: Add enqueue import

        conn
        |> render("new.json", status: "ok")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> render("new.json", status: "error")

        # render(conn, "new.html", changeset: changeset)
    end

    changeset = File.changeset(%File{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = File.changeset(%File{}, %{})
    render(conn, "new.html", changeset: changeset)
  end
end
