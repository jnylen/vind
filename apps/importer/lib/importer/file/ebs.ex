defmodule Importer.File.EBS do
  @moduledoc """
    Importer for EBS-handled Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Word
  alias Importer.Parser.TVAnytimeTiny, as: XMLParser
  alias Importer.Parser.Helper, as: ParserHelper

  import Meeseeks.{XPath}

  require OK
  use OK.Pipe

  # "TUESDAY 30 JULY 2019" (Titlecased)
  @date_format "{WDfull} {D} {Mfull} {YYYY}"

  # "30 JULY 2019" (Titlecased)
  @date_short_format "{D} {Mfull} {YYYY}"

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    require Logger

    cond do
      Regex.match?(~r/\.(doc)$/i, file_name) ->
        import_doc(file, channel)

      Regex.match?(~r/\.(docx)$/i, file_name) ->
        import_docx(file, channel)

      Regex.match?(~r/\.(xml)$/i, file_name) ->
        import_xml(file, channel)

      true ->
        {:error, "not a word/xml file"}
    end
    |> start_batch(channel)
  end

  defp start_batch({:error, reason}, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel) do
    NewBatch.dummy_batch()
    |> process_items(items, channel)
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_new_batch?(item, channel, "00:00", "CET")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp import_xml(file_name, channel),
    do:
      file_name
      |> stream_file!()
      |> XMLParser.parse(channel)

  defp import_doc(file_name, channel) do
    file_name
    |> Word.parse()
    |> case do
      nil ->
        {:error, "wvHtml returned nil"}

      val ->
        val
        |> Okay.replace("<b>", "")
        |> Okay.replace("</b>", "")
        |> Okay.replace("<font color=\"Black\">", "")
        |> Okay.replace("</font>", "")
        |> Meeseeks.all(xpath("//div"))
        |> process_item(nil, channel, nil)
        |> Okay.flatten()
        |> Importer.Parser.Helper.sort_by_start_time()
        |> OK.wrap()
    end
  end

  defp import_docx(file_name, channel) do
    file_name
    |> Word.parse_docx()
    |> case do
      nil ->
        {:error, "wvHtml returned nil"}

      val ->
        val
        |> String.trim_leading(<<0xFEFF::utf8>>)
        |> ParserHelper.fix_known_errors()
        |> String.replace("<br />", ";;;;;")
        |> Meeseeks.all(xpath("//p"))
        |> process_item(nil, channel, nil)
        |> Okay.flatten()
        |> Importer.Parser.Helper.sort_by_start_time()
        |> OK.wrap()
    end
  end

  defp process_item([], _, _, _), do: []

  defp process_item([item | items], date, channel, _previous_airing) do
    item
    |> Meeseeks.text()
    |> Okay.trim()
    |> parse_text()
    |> case do
      {"date", datetime} ->
        process_item(items, datetime, channel, nil)

      {"show", show} ->
        [process_show(date, show, channel) | process_item(items, date, channel, nil)]

      {"text", _text} ->
        ## ADD SYNOPSIS TO PREV AIRING
        process_item(items, date, channel, nil)

      _ ->
        process_item(items, date, channel, nil)
    end
  end

  defp process_show(date, show, channel) do
    datetime =
      date
      |> Timex.set(
        hour: Text.to_integer(show["time"]["hour"]),
        minute: Text.to_integer(show["time"]["mins"])
      )

    %{
      start_time: datetime,
      titles:
        Text.convert_string(
          show["name"]
          |> clean_title(),
          List.first(channel.schedule_languages),
          "content"
        )
    }
  end

  # TODO: Add synopsis to the data

  defp parse_text(""), do: nil
  defp parse_text(nil), do: nil

  defp parse_text(text) do
    cond do
      Regex.match?(~r/^\s*Programme Schedule - \s*$/, text) ->
        "STOP"

      is_show?(text) ->
        {"show", is_show?(text)}

      is_date?(text) ->
        {"date", parse_datetime(text)}

      is_short_date?(text) ->
        {"date", parse_datetime(text)}

      true ->
        {"text", text}
    end
  end

  defp is_show?(text) do
    if Regex.match?(~r/^\d+(\:|\.)\d+/i, text) do
      show = Regex.named_captures(~r/^(?<hour>\d{2}?)(\:|\.)(?<mins>\d{2}?)(?<show>.*)/i, text)

      time = show

      %{"name" => show["show"] |> Okay.trim(), "time" => time}
    else
      false
    end
  end

  defp parse_datetime(date) do
    cond do
      is_date?(date) ->
        Timex.parse!(date |> Text.title_case(), @date_format)

      is_short_date?(date) ->
        Timex.parse!(date |> Text.title_case(), @date_short_format)

      true ->
        {:error, "bad format"}
    end
  end

  defp is_date?(date) do
    case Timex.parse(date |> Text.title_case(), @date_format) do
      {:ok, _} ->
        true

      _ ->
        false
    end
  end

  defp is_short_date?(date) do
    case Timex.parse(date |> Text.title_case(), @date_short_format) do
      {:ok, _} ->
        true

      _ ->
        false
    end
  end

  defp clean_title(title) do
    title
    |> Text.norm()
    |> Okay.replace("(18+)", "")
    |> Okay.trim()
  end
end
