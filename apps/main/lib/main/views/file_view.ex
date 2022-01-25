defmodule Main.FileView do
  use Main, :view
  import Scrivener.HTML
  import Main.ViewHelpers
  import Ecto.Query, only: [from: 2]

  def render("new.json", %{status: "ok"}), do: %{status: "ok"}
  def render("new.json", %{status: "error"}), do: %{status: "error"}

  def try_to_get_channel_name(nil), do: "NIL"

  def try_to_get_channel_name(channel) do
    channel
    |> Map.get(:xmltv_id)
    |> case do
      nil -> "NIL"
      "" -> "NIL"
      name -> name
    end
  end

  def channel_list do
    [{"Select a channel", nil}]
    |> Enum.concat(
      Enum.map(
        all_channels(),
        &{&1.xmltv_id, &1.id}
      )
    )
  end

  def file_url(file) do
    channel = file |> Database.Repo.preload(:channel) |> Map.get(:channel)
    dir = "#{file.source}/#{channel.xmltv_id}"

    Trunk.Storage.S3.build_uri(dir, file.file_name, bucket: "vind-incoming", signed: true)
  end
end
