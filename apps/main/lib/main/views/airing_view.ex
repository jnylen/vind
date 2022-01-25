defmodule Main.AiringView do
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

  def program_type_color("movie"), do: "pink"
  def program_type_color("sports"), do: "green"
  def program_type_color("sports_event"), do: "green"
  def program_type_color(_), do: "blue"
end
