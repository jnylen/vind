defmodule Importer.Web.TV2DK do
  @moduledoc """
  Importer for TV2 Denmark.
  """

  use Importer.Base.Periodic, type: "weekly"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser
  alias Importer.Helpers.Translation

  import SweetXml, except: [parse: 1]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, _batch, _channel, %{body: body} = _data) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Copenhagen")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(item)
    )
  end

  def process(body) do
    body
    |> parse
    ~>> xpath(
      ~x"//programs/program"l,
      start_time:
        ~x".//time/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//title/text()"S |> transform_by(&Text.norm/1),
      content_description: ~x".//description/text()"So |> transform_by(&Text.norm/1),
      genre: ~x".//category/text()"So |> transform_by(&Text.norm/1),
      production_year: ~x".//year/text()"Io,
      episode_num: ~x".//episode/text()"Io,
      original_title: ~x".//original_title/text()"So |> transform_by(&Text.norm/1),
      original_subtitle: ~x".//original_episode_title/text()"So |> transform_by(&Text.norm/1),
      genretext: ~x".//teaser/text()"So,
      production_year: ~x".//year/text()"Io,
      credits: ~x".//cast/text()"So,
      images: [
        ~x"//image"l,
        source: ~x".//url/text()"So,
        copyright: ~x".//byline/text()"So,
        author: ~x".//byline/text()"lSo
      ]
    )
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add genretext parsing
  # TODO: Add original and subtitles.
  defp process_item(%{content_title: nil, original_title: nil}), do: nil

  defp process_item(item) do
    # is_live = Regex.match?(~r/, direkte$/, item[:content_title])
    season = parse_season(item[:original_title])

    %{
      start_time: item[:start_time],
      titles: Text.convert_string(item[:content_title] |> clean_title(), "da", "content"),
      descriptions: Text.convert_string(item[:content_description], "da", "content"),
      episode: item[:episode_num],
      images:
        Enum.map(item[:images], fn data ->
          struct(ImageManager.Image, Map.put(data, :type, "content"))
        end),
      season: season["season"] |> Text.to_integer(),
      production_date: Text.year_to_date(item[:production_year])
    }
    |> append_categories(
      Translation.translate_category(
        "TV2DK",
        item[:genre]
      )
    )
    |> add_credits(item[:credits])
  end

  # Parse season from text
  defp parse_season(nil), do: nil
  defp parse_season(""), do: nil
  defp parse_season(string), do: Regex.named_captures(~r/- .r (?<season>[0-9]+?)$/i, string)

  # Remove shit from the title
  defp clean_title(nil), do: nil
  defp clean_title(""), do: nil

  defp clean_title(string) do
    string
    |> String.replace(~r/\((\d+):(\d+)\)/, "")
    |> String.replace(~r/\((\d+)\)/, "")
    |> String.replace(~r/\, direkte$/, "")
    |> String.replace(~r/\(m\)/, "")
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("%F %T", :strftime)
  end

  # Parse a text string into credits
  def add_credits(airing, string) do
    {_, result} =
      string
      |> String.split("\n")
      |> Okay.reject(&empty_string/1)
      |> Okay.map(fn string ->
        case regexp_credits(string) do
          {:error, _} -> {string, %{}}
          {:ok, result} -> {nil, result}
        end
      end)
      |> Enum.map_reduce(%{}, fn {_, result}, acc ->
        # Change the map a bit, as we need the correct formats
        new_result =
          acc
          |> TextParser.put_non_nil(:credits, parse_people(result["actors"], "actor"))
          |> TextParser.put_non_nil(:credits, parse_people(result["directors"], "director"))
          |> TextParser.put_non_nil(
            :credits,
            parse_people(result["director_and_writer"], "director")
          )
          |> TextParser.put_non_nil(:credits, parse_people(result["writers"], "writer"))
          |> TextParser.put_non_nil(
            :credits,
            parse_people(result["director_and_writer"], "writer")
          )
          |> TextParser.put_non_nil(:credits, parse_people(result["presenters"], "presenter"))

        {result, TextParser.merge_with_lists(acc, new_result)}
      end)

    airing
    |> TextParser.merge_with_lists(result)
  end

  defp parse_people("", _), do: []
  defp parse_people(nil, _), do: []

  defp parse_people(string, type) do
    (string || "")
    |> String.trim()
    |> String.replace(~r/m\.fl\.$/, "")
    |> String.replace(~r/\.$/, "")
    |> String.split(~r/(, | og |\. )/i)
    |> Okay.map(fn person ->
      parsed_person = Regex.named_captures(~r/^(?<role>.*?)\: (?<person>.*?)$/, person)

      %{
        person:
          (parsed_person["person"] || person)
          |> Text.norm(),
        role:
          parsed_person["role"]
          |> Text.norm(),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  ## Credits regex
  defp regexp_credits(string) do
    StringMatcher.new()
    |> StringMatcher.add_regexp(
      ~r/^Medvirkende:(?<actors>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Desuden medvirker:(?<actors>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Instruktion:(?<directors>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Manuskript:(?<writers>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Forfattere:(?<writers>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Producere:(?<producers>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Vært:(?<presenters>.*)/i,
      %{}
    )
    |> StringMatcher.add_regexp(
      ~r/^Instruktion og manuskript:(?<director_and_writer>.*)/i,
      %{}
    )
    |> StringMatcher.match_captures(string |> String.trim())
  end

  # Empty stringer
  defp empty_string(nil), do: true
  defp empty_string(""), do: true
  defp empty_string(_), do: false

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    [_year, week] = String.split(date |> to_string(), "-")

    sprintf(
      "%s?channel=%s&weeknumber=%s&category=&content=",
      [
        config.url_root,
        channel.grabber_info,
        week |> to_string()
      ]
    )
  end
end
