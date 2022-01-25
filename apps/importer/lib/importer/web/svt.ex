defmodule Importer.Web.SVT do
  @moduledoc """
  Importer for Swedish State TV
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.{NewBatch, TextParser, Text, Okay}
  alias Importer.Parser.{TVAnytime, Helper}
  alias Shared.HttpClient

  require OK

  @doc """
  Function to handle inputted data from the Importer Base
  """
  # TODO: PARSE EPISODE NO FROM TITLE
  @impl true
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    body
    |> TVAnytime.parse(channel)
    |> process_items(tuple)
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> process_item()
        |> TVAnytime.remove_episode?()
      )
    )
  end

  # Parse shit from the descriptions
  def process_item(item) do
    item
    |> Map.get(:descriptions, [])
    |> Enum.map(& &1.value)
    |> Enum.reduce(item |> Map.delete(:descriptions), fn x, acc ->
      acc
      |> parse_description(x)
    end)
  end

  def parse_description(airing, desc) do
    results =
      desc
      |> TextParser.split_text()
      |> Okay.map(fn string ->
        case description_regex(string) do
          {:error, _} -> {string, %{}}
          {:ok, result} -> {nil, result}
        end
      end)

    desc =
      results
      |> Okay.map(fn {string, _} ->
        string
      end)
      |> TextParser.join_text()
      |> Text.convert_string("sv", "content")

    {_, result} =
      results
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:credits, parse_credits(result["actors"], "actor"))
          |> TextParser.put_non_nil(:credits, parse_credits(result["directors"], "director"))
          |> TextParser.put_non_nil(:credits, parse_credits(result["presenters"], "presenter"))
          |> TextParser.put_non_nil(:episode, Text.to_integer(result["episode_num"]))
          |> TextParser.put_non_nil(:season, Text.to_integer(result["season_num"]))
          |> TextParser.put_non_nil(:program_type, result["program_type"])

        {result, TextParser.merge_with_lists(acc, new_result)}
      end)

    airing
    |> Helper.merge_list(
      :descriptions,
      desc
    )
    |> TextParser.merge_with_lists(result)
  end

  # Adds the needed regexps and matches the string
  def description_regex(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/långfilm från (\d{4})\.$/i,
      %{"program_type" => "movie"}
    )
    |> StringMatcher.add_regexp(
      ~r/^Säsong (?<season_num>\d+)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Del (?<episode_num>\d+) av (?<of_episode_num>\d+)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^I rollerna: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/från (?<production_year>\d\d\d\d)\.$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Regi: (?<directors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Övriga medverkande: (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^(Medverkande|Röster): (?<actors>.*)$/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Programledare: (?<presenters>.*)$/i,
      %{}
    )
    |> StringMatcher.match_captures(string)
  end

  defp parse_credits("", _), do: []
  defp parse_credits(nil, _), do: []

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(~r/(, | og )/i)
    |> Okay.map(fn person ->
      %{
        person:
          person
          |> Text.norm()
          |> String.replace(~r/m\.fl\.$/, "")
          |> String.replace(~r/\.$/, "")
          |> Text.norm(),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    sprintf("https://api.svt.se/tablatjansten?from=%s&to=%s&channels=%s&format=xml", [
      date,
      date,
      channel.grabber_info
    ])
  end

  @impl true
  def http_client(config, _folder),
    do:
      HttpClient.init(%{
        headers: %{
          "Authorization" => "Bearer #{config.api_key}"
        },
        cookie_jar: CookieJar.new()
      })
end
