defmodule Main.ViewHelpers do
  import Ecto.Query, only: [from: 2]

  def channels_collection do
    [
      [key: "Channel", value: ""]
    ] ++ channels()
  end

  defp channels(), do: all_channels() |> Enum.map(&channel_val/1)

  defp channel_val(c), do: [key: c.xmltv_id, value: c.id]

  def all_channels() do
    from(c in Database.Network.Channel,
      order_by: c.xmltv_id
    )
    |> Database.Repo.all()
  end
end
