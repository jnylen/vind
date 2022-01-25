defmodule Importer.File.SonyGermany do
  @moduledoc """
  Importer for Sony Germany Channels
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
    if file_exists?(file_name) do
      file_name
      |> read_file!()
      |> parse
      ~>> xpath(
        ~x".//broadcast"l,
        start_date: ~x"./start_date/text()"S,
        start_time: ~x"./start_time/text()"S,
        end_date: ~x"./end_date/text()"S,
        end_time: ~x"./end_time/text()"S,
        program_type: ~x"./programme_type/text()"S,
        content_title: ~x"./title/text()"S,
        original_title: ~x"./origtitle/text()"S,
        content_description: ~x"./longtext/text()"S,
        content_subtitle: ~x"./eptitle/text()"S,
        episode_num: ~x"./episode/text()"Io,
        genre: ~x"./category[@type=\"genre\"]/text()"So,
        cast: ~x"./person[@type=\"cast\"]/name/text()"lSo,
        director: ~x"./person[@type=\"director\"]/name/text()"lSo
      )
      |> Okay.map(&process_program(&1, channel))
      |> Okay.reject(&is_nil/1)
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  # TODO: Add more info.
  defp process_program(item, _channel) do
    %{
      start_time: parse_datetime(item.start_date, item.start_time),
      end_time: parse_datetime(item.end_date, item.end_time),
      titles:
        Text.convert_string(
          item.content_title,
          "en",
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
