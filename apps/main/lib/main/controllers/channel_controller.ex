defmodule Main.ChannelController do
  use Main, :controller
  alias Database.Repo
  alias Database.Network.{Airing, Channel}
  import Ecto.Query, only: [from: 2]

  use Filterable.Phoenix.Controller

  filterable(Main.Filters.Channel)

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    {:ok, query, filter_values} = apply_filters(Channel, conn)

    scrivener = query |> Repo.paginate(params)

    render(conn, "index.html",
      page_title: "Channels",
      channels: Map.get(scrivener, :entries),
      meta: filter_values,
      scrivener: scrivener
    )
  end

  def new(conn, %{"channel" => channel_params}) do
    Main.Forms.ChannelForm
    |> create_form(%Database.Network.Channel{}, channel_params)
    |> insert_form_data
    |> case do
      {:ok, channel} ->
        conn
        |> put_flash(:ok, "Channel added successfully.")
        |> redirect(to: "/channel/#{channel.id}")

      {:error, form} ->
        render(conn, "new.html", form: form)
    end
  end

  def new(conn, _params) do
    form = create_form(Main.Forms.ChannelForm, %Database.Network.Channel{})

    render(conn, "new.html", form: form)
  end

  def show(conn, %{"id" => id}) do
    channel = Database.Repo.get(Channel, id)

    render(
      conn,
      "show.html",
      channel: channel,
      airings_count:
        Database.Repo.aggregate(
          from(a in Airing,
            where: a.channel_id == ^channel.id
          ),
          :count
        ),
      files_count:
        Database.Repo.aggregate(
          from(a in Database.Importer.File,
            where: a.channel_id == ^channel.id
          ),
          :count
        ),
      batches_count:
        Database.Repo.aggregate(
          from(a in Database.Importer.Batch,
            where: a.channel_id == ^channel.id
          ),
          :count
        )
    )
  end

  def run_job(conn, %{"ids" => ids, "job" => "run_job"}) do
    ids
    |> Enum.map(fn id ->
      channel = Database.Repo.get(Channel, id)
      Worker.Importer.enqueue(%{"type" => "importer", "channel" => channel.xmltv_id})
    end)

    conn
    |> put_flash(:ok, "Job queued.")
    |> redirect(to: "/channel")
  end

  def run_job(conn, %{"ids" => ids, "job" => "force_update"}) do
    ids
    |> Enum.map(fn id ->
      channel = Database.Repo.get(Channel, id)
      Worker.Importer.enqueue(%{"type" => "importer", "force_update" => channel.xmltv_id})
    end)

    conn
    |> put_flash(:ok, "Job queued.")
    |> redirect(to: "/channel")
  end

  def run_job(conn, %{"id" => id, "job" => "run_job"}) do
    channel = Database.Repo.get(Channel, id)
    Worker.Importer.enqueue(%{"type" => "importer", "channel" => channel.xmltv_id})

    conn
    |> put_flash(:ok, "Job queued.")
    |> redirect(to: "/channel/" <> channel.id)
  end

  def run_job(conn, %{"id" => id, "job" => "force_update"}) do
    channel = Database.Repo.get(Channel, id)
    Worker.Importer.enqueue(%{"type" => "importer", "force_update" => channel.xmltv_id})

    conn
    |> put_flash(:ok, "Job queued.")
    |> redirect(to: "/channel/" <> channel.id)
  end

  def edit(conn, %{"id" => id, "channel" => channel_params} = _params) do
    channel = Database.Repo.get(Channel, id)

    Main.Forms.ChannelForm
    |> create_form(channel, channel_params)
    |> update_form_data
    |> case do
      {:ok, channel} ->
        conn
        |> put_flash(:ok, "Channel updated successfully.")
        |> redirect(to: "/channel/#{channel.id}")

      {:error, form} ->
        render(conn, "edit.html", channel: channel, form: form)
    end
  end

  def edit(conn, %{"id" => id} = _params) do
    channel = Database.Repo.get(Channel, id)
    form = create_form(Main.Forms.ChannelForm, channel)

    render(conn, "edit.html", channel: channel, form: form)
  end

  def delete(conn, %{"id" => id}) do
    Channel
    |> Database.Repo.get(id)
    |> Database.Repo.delete()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Channel removed successfully")
        |> redirect(to: "/channel")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Channel couldn't be removed")
        |> redirect(to: "/channel")
    end
  end
end
