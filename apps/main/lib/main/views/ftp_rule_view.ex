defmodule Main.FtpRuleView do
  use Main, :view
  import Ecto.Query, only: [from: 2]
  import Scrivener.HTML

  def channel_list do
    [{"* Choose a country", nil}]
    |> Enum.concat(
      Enum.map(
        from(c in Database.Network.Channel,
          order_by: c.xmltv_id
        )
        |> Database.Repo.all(),
        &{&1.xmltv_id, &1.id}
      )
    )
  end

  def regex_to_string(""), do: nil
  def regex_to_string(nil), do: nil

  def regex_to_string(%Regex{} = regex) when is_map(regex) do
    regex
    |> Regex.source()
  end

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
