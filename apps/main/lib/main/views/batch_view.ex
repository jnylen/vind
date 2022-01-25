defmodule Main.BatchView do
  use Main, :view
  import Scrivener.HTML
  import Main.ViewHelpers

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
end
