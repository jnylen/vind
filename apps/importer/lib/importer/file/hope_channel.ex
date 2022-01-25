defmodule Importer.File.HopeChannel do
  @moduledoc """
  Importer for Hope Channel
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
    file
    |> process(channel)
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
    if file_exists?(file_name) do
      file_name
      |> read_file!()
      |> parse
      ~>> xpath(
        ~x"//broadcasts"l,
        start_date: ~x"./date/text()"S,
        airings: [
          ~x".//broadcast"l,
          start_time: ~x"./time/text()"S,
          content_title: ~x"./series/text()"S,
          content_subtitle: ~x"./untertitel/text()"S
        ]
      )
      |> Okay.flat_map(&process_date(&1, channel))
      |> Okay.reject(&is_nil/1)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp process_date(%{start_date: date, airings: airings}, channel),
    do: Okay.map(airings, &process_program(&1, date, channel))

  # TODO: Add more info.
  defp process_program(item, date, _channel) do
    %{
      start_time: parse_datetime(date, item.start_time),
      titles:
        Text.convert_string(
          item.content_title,
          "de",
          "content"
        ),
      subtitles:
        Text.convert_string(
          item.content_subtitle,
          "de",
          "content"
        )
    }
  end

  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("%F %H:%M", :strftime)
    |> Timex.to_datetime("Europe/Berlin")
    |> Timex.Timezone.convert("UTC")
  end
end
