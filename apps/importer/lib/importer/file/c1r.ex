defmodule Importer.File.C1R do
  @moduledoc """
  Importer for Channel One Russia
  """

  use Importer.Base.File
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.RTF
  alias Importer.Parser.Helper, as: ParserHelper

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(channel, file_name, file) do
    cond do
      Regex.match?(~r/\.rtf$/i, file_name) ->
        import_rtf(file, channel, file_name)
        |> start_batch(channel, file_name)

      true ->
        {:error, "not a correct format of file"}
    end
  end

  defp start_batch({:error, reason}, _, _), do: {:error, reason}

  defp start_batch({:ok, items}, channel, file_name) do
    NewBatch.start_batch(parse_filename(file_name, channel), channel, "Europe/Moscow")
    |> NewBatch.start_date(file_name |> parse_date_from_file_name(), "00:00")
    |> process_items(items, channel)
  end

  defp process_items(tuple, [], _), do: tuple

  defp process_items(tuple, [item | items], channel) do
    process_items(
      tuple
      |> NewBatch.add_airing(item),
      items,
      channel
    )
  end

  defp import_rtf(file_name, _channel, actual_file_name) do
    file_name
    |> RTF.parse()
    |> process_rtf_airings(nil, actual_file_name)
    |> Okay.flatten()
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_rtf_airings([], _, _), do: []

  defp process_rtf_airings([string | strings], date, filename) do
    # Date?
    cond do
      Regex.match?(~r/^(\d+)\.(\d\d) (.*?)$/i, String.trim(string)) ->
        [time, title] =
          Regex.run(~r/^(\d+\.\d\d) (.*)/, String.trim(string), capture: :all_but_first)

        title =
          Regex.named_captures(
            ~r/"(?<title>.*?)"/i,
            title
          )
          |> case do
            %{"title" => title} -> title
            _ -> title
          end

        [
          %{
            start_time: parse_datetime(time),
            titles:
              Text.convert_string(
                title |> Text.norm(),
                "ru",
                "content"
              )
          }
          | process_rtf_airings(strings, date, filename)
        ]

      true ->
        # Description
        # TODO: ADD DESCRIPTION

        process_rtf_airings(strings, date, filename)
    end
  end

  defp split_text(text) do
    text
    |> Text.norm()
    |> case do
      nil -> []
      str -> str |> String.split(", ")
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(time) do
    import ExPrintf
    [hour, minute] = String.split(time, ".")

    sprintf("%02d:%02d", [
      hour |> String.to_integer(),
      minute |> String.to_integer()
    ])
  end

  defp parse_month_name(string) do
    string
    |> String.downcase()
    |> case do
      "janvarja" -> 1
      "fevralja" -> 2
      "marta" -> 3
      "aprelja" -> 4
      "maja" -> 5
      "ijunja" -> 6
      "ijulja" -> 7
      "avgusta" -> 8
      "sentjabrja" -> 9
      "oktjabrja" -> 10
      "nojabrja" -> 11
      "dekabrja" -> 12
      _ -> nil
    end
  end

  @doc """
  Parse the batch_name from the file_name
  """
  def parse_filename(filename, channel) do
    cond do
      Regex.match?(
        ~r/(?<day>[0-9]{2}?)(?<month>[0-9]{2}?)(?<year>[0-9]{4}?)_/i,
        Path.basename(filename)
      ) ->
        %{"year" => year, "month" => month, "day" => day} =
          Regex.named_captures(
            ~r/(?<day>[0-9]{2}?)(?<month>[0-9]{2}?)(?<year>[0-9]{4}?)_/i,
            Path.basename(filename)
          )

        date =
          Date.new!(
            String.to_integer(year),
            String.to_integer(month),
            String.to_integer(day)
          )

        [
          channel.xmltv_id,
          Timex.format!(date, "%Y-%W", :strftime)
        ]
        |> Enum.join("_")

      true ->
        {:error, "unable to parse batch_name from file_name"}
    end
  end

  def parse_date_from_file_name(filename) do
    %{"year" => year, "month" => month, "day" => day} =
      Regex.named_captures(
        ~r/(?<day>[0-9]{2}?)(?<month>[0-9]{2}?)(?<year>[0-9]{4}?)_/i,
        Path.basename(filename)
      )

    Date.new!(
      String.to_integer(year),
      String.to_integer(month),
      String.to_integer(day)
    )
  end
end
