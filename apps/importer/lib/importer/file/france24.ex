defmodule Importer.File.France24 do
  @moduledoc """
  Importer for France24
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Shared.Zip

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    require Logger

    if Regex.match?(~r/\.xml$/i, file_name) do
      # XML
      import_xml(file, channel)
    else
      {:error, "not a zip or xml file"}
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
      |> NewBatch.start_new_batch?(item, channel)
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp import_xml(file_name, channel) do
    file_name
    |> read_file!()
    |> parse
    ~>> xpath(
      ~x"//Programme"l,
      start_time: ~x".//CalendarTime/text()"S |> transform_by(&parse_datetime/1),
      content_title: ~x".//Genre/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//ProgCat/text()"S |> transform_by(&Text.norm/1),
      is_live: ~x".//Live/text()"S |> transform_by(&Text.norm/1)
    )
    |> Okay.map(&process_item(&1, channel))
    |> Okay.flatten()
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_item(program, channel) do
    %{
      start_time: program.start_time,
      titles:
        Text.convert_string(
          program.content_title |> capitalize(),
          List.first(channel.schedule_languages),
          "content"
        )
    }

    # TODO: Add genres
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> String.replace(~r/\:00$/, "")
    |> DateTimeParser.parse_datetime(to_utc: true)
    |> case do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  defp capitalize(string) do
    string
    |> String.split()
    |> Okay.map(&String.capitalize/1)
    |> Okay.join(" ")
  end
end
