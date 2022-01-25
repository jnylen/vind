# TODO: Add doc parsing
defmodule Importer.File.RTVE do
  @moduledoc """
  Importer for RTVE/TVE Channels
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Word

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    cond do
      Regex.match?(~r/\.xml$/i, file_name) ->
        import_xml(file, channel)
        |> start_batch(channel, parse_filename(file_name, channel))

      Regex.match?(~r/\.html$/i, file_name) ->
        import_html(file, channel)
        |> start_batch(channel, parse_filename(file_name, channel))

      Regex.match?(~r/\.doc$/i, file_name) ->
        import_doc(file, channel)
        |> process_items_new_batch(NewBatch.dummy_batch(), channel)

      true ->
        {:error, "not a correct format of file"}
    end
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    NewBatch.start_batch(batch_name, channel, "Europe/Madrid")
    |> process_items(items, channel)
  end

  defp process_items_new_batch({:ok, items}, tuple, channel) when is_list(items),
    do: process_items_new_batch(tuple, items, channel)

  defp process_items_new_batch(tuple, [], _), do: tuple

  defp process_items_new_batch(tuple, [item | items], channel) do
    process_items_new_batch(
      tuple
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  def import_doc(file_name, channel) do
    file_name
    |> Word.parse()
    |> Okay.replace(~r/<(\/|)meta(.*?)>/i, "")
    |> Okay.replace(~r/<(\/|)br>/i, "")
    |> Okay.replace(~r/<(\/|)img(.*?)>/i, "")
    |> Okay.replace(~r/<p>/i, "")
    |> Okay.replace(~r/<(\/|)b>/i, "")
    |> parse()
    ~>> xpath(~x"//p/text()"Sl)
    |> process_doc_airings(nil, channel)
    |> OK.wrap()
  end

  # TODO: Add extra info such as cast
  defp import_xml(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x".//Event"l,
      start_time: ~x"./@beginTime"S |> transform_by(&parse_datetime/1),
      original_title:
        ~x"./EpgProduction/EpgText/ExtendedInfo[@name=\"Original Event Name\"]/text()"So
        |> transform_by(&Text.norm/1),
      original_subtitle:
        ~x"./EpgProduction/EpgText/ExtendedInfo[@name=\"Original Episode Name\"]/text()"So
        |> transform_by(&Text.norm/1),
      content_title: ~x"./EpgProduction/EpgText/Name/text()"S |> transform_by(&Text.norm/1),
      content_subtitle:
        ~x"./EpgProduction/EpgText/ExtendedInfo[@name=\"Episode Name\"]/text()"So
        |> transform_by(&Text.norm/1),
      episode_no: ~x"./EpgProduction/EpgText/ExtendedInfo[@name=\"Episode Number\"]/text()"Io,
      content_short_description:
        ~x"./EpgProduction/EpgText/ShortDescription/text()"So |> transform_by(&Text.norm/1),
      content_description:
        ~x"./EpgProduction/EpgText/Description/text()"So |> transform_by(&Text.norm/1),
      directors:
        ~x"./EpgProduction/EpgText/ExtendedInfo[@name=\"Director\"]/text()"So
        |> transform_by(&split_text/1)
    )
    |> Okay.map(&process_program(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp import_html(file_name, _channel) do
    file_name
    |> read_file!()
    |> Okay.replace("</HEAD>", "</HEAD><BODY>")
    |> Okay.replace("<HR>", "")
    |> Okay.replace(~r/<SPAN>/i, "<span>")
    |> Okay.replace(~r/<(\/|)U>/i, "")
    |> Okay.replace(~r/<(\/|)STRONG>/i, "")
    |> Okay.replace(" & ", " &amp; ")
    |> Okay.replace(~r/<\/SPAN>/i, "</span>")
    |> parse()
    ~>> xpath(~x"//P/text()"Sl)
    |> process_html_airings(nil)
    |> Okay.flatten()
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_doc_airings([], _, _), do: []

  defp process_doc_airings([string | strings], date, channel) do
    # Date?
    cond do
      Regex.match?(~r/^PROGRAMACI.N/iu, String.trim(string)) &&
          Regex.match?(~r/(\d+) DE (.*?)$/u, String.trim(string)) ->
        if Regex.match?(~r/#{channel.grabber_info}/iu, String.trim(string)) do
          process_doc_airings(
            strings,
            nil,
            channel
          )
        else
          # DATE
          [day, monthname] =
            Regex.run(~r/(\d+) DE (.*?)$/, String.trim(string), capture: :all_but_first)

          {:ok, new_date} =
            Date.new(
              guess_year(monthname |> parse_month_name()),
              monthname |> parse_month_name(),
              day |> String.to_integer()
            )

          process_doc_airings(
            strings,
            new_date,
            channel
          )
        end

      !is_nil(date) && Regex.match?(~r/^(\d\d)\:(\d\d) (.*?)$/i, String.trim(string)) ->
        [time, title] =
          Regex.run(~r/^(\d\d\:\d\d) (.*)/, String.trim(string), capture: :all_but_first)

        [
          %{
            start_time: parse_datetime(date, time),
            titles:
              Text.convert_string(
                title |> Text.norm(),
                "es",
                "content"
              )
          }
        ]
        |> Okay.concat(process_doc_airings(strings, date, channel))

      true ->
        # Description
        # TODO: ADD DESCRIPTION

        process_doc_airings(strings, date, channel)
    end
  end

  defp process_html_airings([], _), do: []

  defp process_html_airings([string | strings], date) do
    # Date?
    cond do
      Regex.match?(~r/^PROGRAMACION/i, String.trim(string)) &&
          Regex.match?(~r/(\d+) DE (.*?) DE (\d\d\d\d)$/, String.trim(string)) ->
        # DATE
        [day, monthname, year] =
          Regex.run(~r/(\d+) DE (.*?) DE (\d\d\d\d)$/, String.trim(string),
            capture: :all_but_first
          )

        {:ok, new_date} =
          Date.new(
            year |> String.to_integer(),
            monthname |> parse_month_name(),
            day |> String.to_integer()
          )

        process_html_airings(
          strings,
          new_date
        )

      Regex.match?(~r/^(\d\d)\:(\d\d) (.*?)$/i, String.trim(string)) ->
        [time, title] =
          Regex.run(~r/^(\d\d\:\d\d) (.*)/, String.trim(string), capture: :all_but_first)

        [
          %{
            start_time: parse_datetime(date, time),
            titles:
              Text.convert_string(
                title |> Text.norm(),
                "es",
                "content"
              )
          }
        ]
        |> Okay.concat(process_html_airings(strings, date))

      true ->
        # Description
        # TODO: ADD DESCRIPTION

        process_html_airings(strings, date)
    end
  end

  # TODO: Add more info.
  defp process_program(item, _channel) do
    %{
      start_time: item.start_time,
      titles:
        Text.convert_string(
          item.content_title,
          "es",
          "content"
        ),
      subtitles:
        Text.convert_string(
          item.content_subtitle,
          "es",
          "content"
        ),
      episode: item[:episode_no]
    }
  end

  defp split_text(text) do
    text
    |> Text.norm()
    |> case do
      nil -> []
      str -> str |> String.split(", ")
    end
  end

  defp parse_datetime(date, time) do
    [hour, minute] = String.split(time, ":")

    date
    |> Timex.to_datetime()
    |> Timex.set(
      hour: hour |> String.to_integer(),
      minute: minute |> String.to_integer()
    )
    |> Timex.to_datetime("Europe/Madrid")
    |> Timex.Timezone.convert("UTC")
  end

  # XML
  defp parse_datetime(datetime) do
    datetime
    |> Timex.parse("%Y%m%d%H%M%S", :strftime)
    |> case do
      {:ok, date} ->
        date
        |> Timex.to_datetime("Europe/Madrid")
        |> Timex.Timezone.convert("UTC")

      val ->
        val
    end
  end

  defp parse_month_name(string) do
    string
    |> String.downcase()
    |> case do
      "enero" -> 1
      "febrero" -> 2
      "marzo" -> 3
      "abril" -> 4
      "mayo" -> 5
      "junio" -> 6
      "julio" -> 7
      "agosto" -> 8
      "septiembre" -> 9
      "octubre" -> 10
      "noviembre" -> 11
      "diciembre" -> 12
      _ -> nil
    end
  end

  @doc """
  Parse the batch_name from the file_name
  """
  def parse_filename(filename, channel) do
    import ExPrintf

    cond do
      Regex.match?(
        ~r/(?<year>[0-9]{2}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)/i,
        Path.basename(filename)
      ) ->
        %{"year" => year, "month" => month, "day" => day} =
          Regex.named_captures(
            ~r/(?<year>[0-9]{2}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)/i,
            Path.basename(filename)
          )

        # "#{year}-#{month}-#{day}"
        sprintf("%s_%04d-%02d-%02d", [
          channel.xmltv_id,
          String.to_integer(year) + 2000,
          String.to_integer(month),
          String.to_integer(day)
        ])

      Regex.match?(~r/SEMANA (?<week>[0-9]{1,2}?)/i, Path.basename(filename)) ->
        %{"week" => week} =
          Regex.named_captures(
            ~r/SEMANA (?<week>[0-9]{1,2}?)/i,
            Path.basename(filename)
          )

        # Lets just guess the year is current year
        sprintf("%s_%04d-%02d", [
          channel.xmltv_id,
          Date.utc_today().year + 2000,
          String.to_integer(week)
        ])

      true ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end

  defp guess_year(month_no) do
    if Date.utc_today().month < month_no do
      Date.utc_today().year + 1
    else
      Date.utc_today().year
    end
  end
end
