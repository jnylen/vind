defmodule Importer.File.CNBC do
  @moduledoc """
    Importer for CNBC Europe
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    process(file, channel)
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
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x".//Group[@Level=\"1\"]"l,
      start_date:
        ~x"./GroupHeader/Section/Field[@Name=\"FDQTRSCHNUMDATE1\"]/Value/text()"S
        |> transform_by(&parse_date/1),
      programs: [
        ~x".//Group[@Level=\"2\"]"l,
        start_time: ~x"./GroupHeader/Section/Field[@Name=\"hour1\"]/Value/text()"S,
        content_title:
          ~x"./GroupHeader/Section/Field[@Name=\"programName1\"]/Value/text()"S
          |> transform_by(&cleanup_title/1)
      ]
    )
    |> Okay.flat_map(&process_day(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_day(days, channel) do
    days.programs
    |> Okay.map(&process_program(&1, days.start_date, channel))
  end

  # TODO: Parse Episode title.
  defp process_program(item, date, _channel) do
    titles = item.content_title |> String.split(" : ")

    %{
      start_time: parse_datetime(date, item.start_time),
      titles:
        Text.convert_string(
          Enum.at(titles, 0) |> cleanup_title(),
          "en",
          "content"
        )
    }
  end

  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%F %H:%M:%S", :strftime)
    |> Timex.to_datetime("GMT")
    |> Timex.Timezone.convert("UTC")
  end

  defp parse_date(datetime) do
    datetime
    |> Timex.parse!("%FT%T", :strftime)
    |> Timex.to_date()
    |> Okay.to_string()
  end

  defp cleanup_title(title) do
    title
    |> Okay.replace(~r/^L\-/i, "")
    |> Okay.replace(
      ~r/(1st hr|2nd & 3rd hr|2nd hr|3rd hr|1st hour|1 hour|2nd hour|3rd hour|\(UNSPONSORED\)|\(f\)|\(g\))/i,
      ""
    )
    |> Okay.replace(~r/\#(\d+) Hour(s|)/i, "")
    |> Okay.replace(~r/\((\d+) Part(|s)\)/i, "")
    # |> Okay.replace(~r/Series (\d+)/i, "")
    |> Okay.replace(~r/\#(\d+)( |)min/i, "")
    |> Okay.replace(~r/\#(\d+)/i, "")
    # |> Okay.replace("/", "")
    |> Text.norm()
    |> Okay.replace(~r/\:$/i, "")
    |> Okay.trim()
    |> Okay.replace(~r/\/$/i, "")
    |> Okay.trim()
    |> Okay.replace(~r/\-$/i, "")
    |> Okay.trim()
    |> capitalize_per_word()
    |> Okay.replace(~r/cnbc/i, "CNBC")
  end

  defp capitalize_per_word(nil), do: ""

  defp capitalize_per_word(string) do
    string
    |> String.split()
    |> Okay.map(&String.capitalize/1)
    |> Okay.reject(&is_blank?/1)
    |> Okay.join(" ")
  end

  defp is_blank?(""), do: true
  defp is_blank?(nil), do: true
  defp is_blank?(_), do: false
end
