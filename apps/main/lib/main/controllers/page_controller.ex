defmodule Main.PageController do
  use Main, :controller
  import Ecto.Query, only: [from: 2]
  alias Database.Importer.{File, Batch}
  alias Database.Network.{Airing}
  alias Database.Repo
  alias Database.Image.File, as: Image

  def index(conn, _params) do
    render(conn, "index.html",
      files_today: files_today(),
      files_total: files_total(),
      batches_today: batches_today(),
      batches_total: batches_total(),
      airings_today: airings_today(),
      airings_total: airings_total(),
      images_today: images_today(),
      images_total: images_total()
    )
  end

  defp files_today do
    from(f in File,
      where: f.inserted_at >= ^Timex.beginning_of_day(today()),
      where: f.inserted_at <= ^Timex.end_of_day(today())
    )
    |> Repo.aggregate(:count, :id)
  end

  defp files_total do
    File
    |> Repo.aggregate(:count, :id)
  end

  defp batches_today do
    from(b in Batch,
      where: b.updated_at >= ^Timex.beginning_of_day(today()),
      where: b.updated_at <= ^Timex.end_of_day(today())
    )
    |> Repo.aggregate(:count, :id)
  end

  defp batches_total do
    Batch
    |> Repo.aggregate(:count, :id)
  end

  defp airings_today do
    from(a in Airing,
      where: a.updated_at >= ^Timex.beginning_of_day(today()),
      where: a.updated_at <= ^Timex.end_of_day(today())
    )
    |> Repo.aggregate(:count, :id)
  end

  defp airings_total do
    Airing
    |> Repo.aggregate(:count, :id)
  end

  defp images_today do
    from(a in Image,
      where: a.updated_at >= ^Timex.beginning_of_day(today()),
      where: a.updated_at <= ^Timex.end_of_day(today())
    )
    |> Repo.aggregate(:count, :id)
  end

  defp images_total do
    Image
    |> Repo.aggregate(:count, :id)
  end

  defp today(), do: DateTime.utc_now()
end
