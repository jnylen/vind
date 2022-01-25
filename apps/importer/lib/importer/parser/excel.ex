defmodule Importer.Parser.Excel do
  @behaviour Saxy.Handler

  alias Importer.Parser.Helper

  def parse(file_path, format, channel \\ nil, worksheet \\ nil)

  def parse(file_path, "xml", channel, _worksheet) do
    {:ok, path} = Briefly.create(extname: ".xml")

    System.cmd("ssconvert", [file_path, "--recalc", "--export-type=Gnumeric_XmlIO:sax:0", path])

    parse_xml(path, channel)
  end

  def parse(file_path, "csv", channel, worksheet) do
    {:ok, path} = Briefly.create(extname: ".csv")

    #### Disabled due to old version in dokku
    #### Needs at least 1.12.49
    #    if worksheet do
    #      System.cmd(
    #        "ssconvert",
    #        [
    #          file_path,
    #          "--recalc",
    #          "-O",
    #          "sheet='#{worksheet}'",
    #          "--export-type=Gnumeric_stf:stf_csv",
    #          path
    #        ]
    #        |> IO.inspect()
    #      )
    #    else
    System.cmd("ssconvert", [file_path, "--recalc", "--export-type=Gnumeric_stf:stf_csv", path])
    #    end

    parse_csv(path, channel)
  end

  @doc """
  Trim a string into the correct way and remove some unwanted shit.
  """
  def trim(nil), do: ""
  def trim(""), do: ""
  def trim(%{value: val}), do: val |> trim()

  def trim(string),
    do:
      string |> String.replace("\uFEFF", "") |> String.split() |> Enum.join(" ") |> String.trim()

  @doc """
  Parse field names based on an array of regexs
  """
  def field_names(rows, list_of_regex, required_key \\ :start_date)

  def field_names([], _, _), do: {:error, "no field names found"}

  def field_names([row | rows], list_of_regex, required_key) do
    row
    |> Enum.with_index()
    |> Enum.map(&regex_reduce(&1, list_of_regex))
    |> List.flatten()
    |> case do
      [] ->
        field_names(rows, list_of_regex, required_key)

      matched ->
        case Keyword.has_key?(matched, required_key) do
          true -> {:ok, matched}
          false -> field_names(rows, list_of_regex, required_key)
        end
    end
  end

  def parse_xml(file_path, channel) do
    file_path
    |> File.stream!()
    |> Stream.filter(&(&1 != "\n"))
    |> Stream.map(&Helper.fix_known_errors/1)
    |> Saxy.parse_stream(__MODULE__, {nil, [], {nil, channel}})
  end

  def parse_csv(file_path, channel) do
    {_, rows} =
      file_path
      |> File.stream!()
      |> Stream.filter(&(&1 != "\n"))
      |> Stream.map(&Helper.fix_known_errors/1)
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
      |> Enum.reduce({0, []}, fn item, {num, acc} ->
        {_, cells} =
          Enum.reduce(item, {0, []}, fn item_col, {num_col, acc} ->
            {
              num_col + 1,
              [
                %{
                  row: num,
                  col: num_col,
                  value: item_col
                }
                | acc
              ]
            }
          end)

        {
          num + 1,
          [
            Enum.sort_by(cells, fn cell ->
              Map.get(cell, :col)
            end)
            | acc
          ]
        }
      end)

    {
      :ok,
      Enum.reverse(rows)
    }
  end

  # Sheet
  def handle_event(:start_element, {"gnm:Sheet", _attributes}, {nil, cells, {_, channel}}),
    do: {:ok, {"gnm:Sheet", cells, {nil, channel}}}

  def handle_event(:start_element, {"gnm:Name", _attributes}, {"gnm:Sheet", cells, channel}),
    do: {:ok, {"gnm:SheetName", cells, channel}}

  def handle_event(:characters, chars, {"gnm:SheetName", cells, channel}),
    do: {:ok, {nil, cells, {chars, channel}}}

  # Start of an cell
  def handle_event(:start_element, {"Cell", attributes}, {nil, cells, channel}),
    do: handle_cell(:start_element, attributes, {nil, cells, channel})

  def handle_event(:characters, chars, {"Cell", [cell | cells], channel}),
    do: handle_cell(:characters, chars, {"Cell", [cell | cells], channel})

  def handle_event(:end_element, {"Cell", _}, {v, cells, channel}),
    do: handle_event(:end_element, {v, cells, channel})

  def handle_event(:start_element, {"gnm:Cell", attributes}, {nil, cells, channel}),
    do: handle_cell(:start_element, attributes, {nil, cells, channel})

  def handle_event(:characters, chars, {"gnm:Cell", [cell | cells], channel}),
    do: handle_cell(:characters, chars, {"gnm:Cell", [cell | cells], channel})

  def handle_event(:end_element, {"gnm:Cell", _}, {v, cells, channel}),
    do: handle_event(:end_element, {v, cells, channel})

  ### Catch-all:s
  def handle_event(:characters, _chars, state), do: {:ok, state}

  def handle_event(:start_element, {_name, _attributes}, state) do
    {:ok, state}
  end

  def handle_event(:end_element, _name, state) do
    {:ok, state}
  end

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, {_, cells, _}) do
    cells
    |> Enum.sort_by(fn cell ->
      Map.get(cell, :col)
    end)
    |> Enum.group_by(fn cell ->
      Map.get(cell, :sheet, "")
      |> String.trim()
    end)
    |> Enum.into([])
    |> Enum.map(fn {sheet_name, rows} ->
      {
        sheet_name,
        rows
        |> Enum.group_by(fn cell ->
          Map.get(cell, :row)
        end)
        |> Enum.sort_by(fn {i, _} ->
          i
        end)
        |> Enum.map(fn {_, i} -> i end)
      }
    end)
    |> Enum.into(%{})
    |> OK.wrap()
  end

  def handle_cell(:start_element, attributes, {nil, cells, {sheet_name, channel}}) do
    attributes = attributes |> Enum.into(%{})

    cell = %{
      sheet: sheet_name,
      row: String.to_integer(Map.get(attributes, "Row")),
      col: String.to_integer(Map.get(attributes, "Col")),
      value: nil
    }

    {:ok, {"Cell", [cell | cells], {sheet_name, channel}}}
  end

  def handle_cell(:characters, chars, {"Cell", [cell | cells], channel}) do
    {:ok, {nil, [Map.put(cell, :value, chars) | cells], channel}}
  end

  def handle_event(:end_element, {_, cells, channel}) do
    # List.first(cells) |> IO.inspect()

    {:ok, {nil, cells, channel}}
  end

  def has_errors?(results) when is_list(results) do
    # Tag it as error if :error is found
    if Keyword.has_key?(results, :error) && results |> only_errors?() do
      {:error, Keyword.get(results, :error)}
    else
      if Keyword.has_key?(results, :error) do
        results
        |> Enum.reject(&is_error?/1)
      else
        results
      end
      |> List.flatten()
    end
  end

  def has_errors?(_), do: {:error, "a list wasn't returned"}

  defp only_errors?(list) when is_list(list) do
    list |> Enum.reject(&is_error?/1) |> Enum.empty?()
  end

  defp is_error?({:error, _}), do: true
  defp is_error?(_), do: false

  # Reduce regex
  defp regex_reduce({text, index}, list_of_regex) do
    list_of_regex
    |> Enum.reduce_while(
      [],
      &regex_match!(&1, &2, text |> trim(), index)
    )
  end

  # Does the regex match?
  defp regex_match!(_, _, nil, _), do: {:cont, []}
  defp regex_match!(_, _, "", _), do: {:cont, []}

  defp regex_match!(regex, _, text, index) do
    if regex_match?(regex, text |> trim()),
      do: {:halt, Keyword.put([], regex.type, index)},
      else: {:cont, []}
  end

  defp regex_match?(%{regex: _}, nil), do: false
  defp regex_match?(%{regex: _}, ""), do: false

  defp regex_match?(%{regex: regex}, text),
    do: Regex.match?(regex, text)
end
