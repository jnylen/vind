defmodule Importer.File.RussiaToday do
  use Importer.Base.File

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Text
  alias Importer.Parser.Helper
  alias Importer.Parser.RussiaTodayCSV, as: Parser


  @fields %{
    "date" => 0,
    "start_time" => 1,
    "end_time" => 2,
    "content_title" => 3,
    "program_type" => 4,
    "genre" => 5,
    "content_description" => 6
  }

  @moduledoc """
  Importer for channels aired by Russia Today.
  """

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    file
    |> process_file(channel)
    |> start_batch(channel, parse_filename(file_name, channel))
  end

  defp start_batch(_, _, {:error, reason}), do: {:error, reason}
  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, batch_name) do
    batch_name
    |> NewBatch.start_batch(channel, "Europe/Moscow")
    |> process_batch_items(items, channel)
  end

  defp process_batch_items(tuple, [], _), do: tuple

  defp process_batch_items(tuple, [item | items], channel) do
    process_batch_items(
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp process_file(file_name, channel) do
    if file_exists?(file_name) do
      file_name
      |> read_file!()
      |> replace_string("\uFEFF", "")
      |> Parser.parse_string()
      |> Enum.filter(fn airing ->
        airing |> length() > 2
      end)
      |> Enum.map(&process_item(&1, channel))
      |> Enum.reject(&is_nil/1)
      |> Helper.sort_by_start_time()
      |> OK.wrap()
    else
      {:error, "file does not exist"}
    end
  end

  defp process_item(airing, channel) do
    if String.printable?(Enum.at(airing, @fields["date"])) and
         Regex.match?(~r/(\d)/, Enum.at(airing, @fields["date"])) do
      %{
        start_time:
          parse_datetime(Enum.at(airing, @fields["date"]), Enum.at(airing, @fields["start_time"]))
      }
      |> Helper.merge_list(
        :titles,
        Text.string_to_map(
          airing |> Enum.at(@fields["content_title"]) |> Text.norm(),
          List.first(channel.schedule_languages),
          "content"
        )
      )
      |> Helper.merge_list(
        :description,
        Text.string_to_map(
          airing |> Enum.at(@fields["content_description"]) |> Text.norm(),
          List.first(channel.schedule_languages),
          "content"
        )
      )
    else
      nil
    end
  end

  defp parse_datetime(date, time) do
    "#{date} #{time}"
    |> Timex.parse!("{D}/{M}/{YY} {h24}:{m}")
  end

  # Parse the batch_name from the file_name
  def parse_filename(filename, channel) do
    import ExPrintf

    case Regex.named_captures(
           ~r/_(?<year>[0-9]{4}?)(?<month>[0-9]{2}?)(?<day>[0-9]{2}?)/i,
           Path.basename(filename)
         ) do
      %{"year" => year, "month" => month, "day" => day} ->
        {:ok, week} =
          {year |> String.to_integer(), month |> String.to_integer(), day |> String.to_integer()}
          |> Date.from_erl!()
          |> Timex.format("%Y-%W", :strftime)

        # "#{year}-#{month}-#{day}"
        sprintf("%s_%s", [
          channel.xmltv_id,
          week
        ])

      _ ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end

  defp replace_string({:ok, value}, replace, replace_with), do: replace_string(value, replace, replace_with)
  defp replace_string(value, replace, replace_with) do
    value
    |> String.replace(replace, replace_with)
  end
end
