# TODO: Add doc parsing
defmodule Importer.File.TVN do
  @moduledoc """
  Importer for TVN Channels
  """

  use Importer.Base.File
  alias Importer.Helpers.{NewBatch}
  alias Importer.Parser.{Excel, TVN}
  alias Importer.Helpers.Text
  alias Importer.Parser.Helper
  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    cond do
      Regex.match?(~r/\.docx$/i, file_name) ->
        import_docx(file, channel)
        |> start_batch(channel)

      Regex.match?(~r/\.(xlsx|xls)$/i, file_name) ->
        import_xls(file, channel)
        |> start_batch(channel)

      true ->
        {:error, "not a correct format of file"}
    end
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
      |> NewBatch.start_new_batch?(item, channel, "00:00", "Europe/Stockholm")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  def import_docx(file_name, channel) do
    file_name
    |> TVN.parse(channel)
    |> parse_doc_airings()
    |> OK.wrap()
  end

  def import_xls(file_name, channel) do
    if Application.get_env(:main, :environment) != :prod do
      require Logger
      Logger.debug("Parsing #{file_name}..")
    end

    # Parse excel
    {:ok, programs} = Excel.parse(file_name, "csv")

    []
    |> parse_xls_text(
      Enum.map(programs, fn prog -> Enum.map(prog, fn prog -> Map.get(prog, :value) end) end),
      channel
    )
    |> parse_xls_airings()
    |> Enum.reject(&is_nil/1)
    |> Helper.sort_by_start_time()
    |> OK.wrap()
  end

  defp parse_doc_airings({:ok, airings}), do: parse_doc_airing(nil, airings)

  defp parse_doc_airing(_date, [{"date", val} | airings]), do: parse_doc_airing(val, airings)

  defp parse_doc_airing(date, [{"airing", map} | airings]) do
    [
      # |> parse_datetime())
      map |> Map.put(:start_time, "#{date} #{Map.get(map, :start_time)}" |> parse_datetime())
      | parse_doc_airing(date, airings)
    ]
  end

  defp parse_doc_airing(nil, [_ | airings]), do: parse_doc_airing(nil, airings)

  defp parse_doc_airing(_date, []), do: []

  defp parse_xls_airings({:ok, airings}), do: parse_xls_airing(nil, airings)
  defp parse_xls_airing(_date, [{"date", val} | airings]), do: parse_xls_airing(val, airings)

  defp parse_xls_airing(date, [{"airing", map} | airings]) do
    [
      # |> parse_datetime())
      map |> Map.put(:start_time, "#{date} #{Map.get(map, :start_time)}" |> parse_datetime())
      | parse_xls_airing(date, airings)
    ]
  end

  defp parse_xls_airing(nil, [_ | airings]), do: parse_xls_airing(nil, airings)
  defp parse_xls_airing(_date, []), do: []

  defp parse_xls_text(list, [], _), do: list |> Enum.reverse() |> OK.wrap()

  defp parse_xls_text(list, [string | strings], channel) do
    cond do
      is_date?(string) ->
        {:ok, date} = string |> parse_date()

        [{"date", date} | list]
        |> parse_xls_text(strings, channel)

      xls_is_show?(string) ->
        {:ok, airing} = string |> parse_xls_text_airing()

        [{"airing", airing} | list]
        |> parse_xls_text(strings, channel)

      true ->
        list
        |> parse_xls_text(strings, channel)
    end
  end

  defp parse_datetime(string) do
    case DateTimeParser.parse_datetime(string, to_utc: true) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  defp xls_is_show?(strings) do
    strings
    |> List.first()
    |> parse_time_float()
    |> case do
      :error ->
        false

      val ->
        Regex.match?(~r/^(\d{1,2})\:(\d\d)\:(\d\d)$/i, val)
    end
  end

  defp xls_is_show?(_), do: false

  def is_date?(strings) do
    string = strings |> List.first() |> String.replace(" ", "")

    Regex.match?(
      ~r/^(.*?),(.*?),(\d{4})-(\d{2})-(\d{2})$/i,
      string
    )
  end

  defp parse_date(strings) do
    string = strings |> List.first() |> String.replace(" ", "")

    case Regex.named_captures(
           ~r/^(.*?),(.*?),(?<date>\d{4}-\d{2}-\d{2})$/i,
           string
         ) do
      %{
        "date" => date
      } ->
        DateTimeParser.parse_date(date)

      _ ->
        nil
    end
  end

  defp parse_xls_text_airing(strings) do
    time = strings |> List.first()
    title = strings |> List.delete_at(0) |> List.first()
    episode = strings |> List.delete_at(0) |> List.delete_at(0) |> List.first()

    start_time = time |> parse_time_float()

    case Regex.named_captures(~r/(?<title>.*)\s+\-\s+(?<subtitle>.*)$/i, title) do
      %{
        "subtitle" => subtitle,
        "title" => title
      } ->
        new_title =
          unless is_nil(episode |> String.trim()) do
            "#{title |> String.replace(start_time, "")} (#{String.trim(episode)})"
          else
            title |> String.replace(start_time, "")
          end

        %{
          start_time: start_time |> String.replace(".", ":")
        }
        |> TVN.parse_title(new_title)
        |> TVN.parse_subtitle(subtitle)

      _ ->
        %{
          start_time: start_time |> String.replace(".", ":")
        }
        |> Helper.merge_list(
          :titles,
          Text.string_to_map(
            title |> Text.norm(),
            "pl",
            "content"
          )
        )
    end
    |> OK.wrap()
  end

  defp parse_time_float(string) do
    case DateTimeParser.parse_time(string) do
      {:ok, time} -> to_string(time)
      _ -> :error
    end
  end

  defp parse_time_float(_), do: :error
end
