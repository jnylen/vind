defmodule Main.ExportView do
  use Main, :view
  import Scrivener.HTML

  def to_column_header(date) do
    if Date.utc_today() == date do
      "<th scope='col' class='today'>#{date |> Timex.format!("%m-%d", :strftime)}</th>"
    else
      "<th scope='col'>#{date |> Timex.format!("%m-%d", :strftime)}</th>"
    end
  end

  def to_column(nil, _day, _xmltv_id), do: nil

  def to_column(true, day, xmltv_id) do
    if Date.utc_today() == day do
      "<td class='X today'><a href='http://xmltv.xmltv.se/#{xmltv_id}_#{day}.xml'>X</a></td>"
    else
      "<td class='X'><a href='http://xmltv.xmltv.se/#{xmltv_id}_#{day}.xml'>X</a></td>"
    end
  end

  def to_column(false, day, xmltv_id) do
    if Date.utc_today() == day do
      "<td class='E today'><a href='http://xmltv.xmltv.se/#{xmltv_id}_#{day}.xml'>E</a></td>"
    else
      "<td class='E'><a href='http://xmltv.xmltv.se/#{xmltv_id}_#{day}.xml'>E</a></td>"
    end
  end

  def new_xmltv_id?(channel) do
    channel.new_xmltv_id || channel.xmltv_id
  end
end
