defmodule Importer.Web.Axess do
  @moduledoc """
  Importer for Axess
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.TextParser
  alias Importer.Helpers.Translation

  import SweetXml, except: [parse: 2]
  import Importer.Helpers.Xml

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base

  The data received from Axess is in latin1
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body}) do
    body
    |> process(
      tuple
      |> NewBatch.set_timezone("Europe/Stockholm")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process(body, tuple) do
    body
    |> parse(encoding: 'latin1')
    ~>> xpath(
      ~x"//TVRProgramBroadcast"l,
      start_time:
        ~x".//TVRBroadcast/BroadcastDateTime/StartDateTime/text()"S
        |> transform_by(&parse_datetime/1),
      end_time:
        ~x".//TVRBroadcast/BroadcastDateTime/EndDateTime/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: [
        ~x".//TVRProgram",
        value: ~x"./Title/text()"S,
        language: ~x"./Title/@LanguageCode"S |> transform_by(&Text.convert_language/1)
      ],
      series_title: [
        ~x".//TVRProgram",
        value: ~x"./SeriesSeason/Title/text()"S,
        language: ~x"./Title/@LanguageCode"S |> transform_by(&Text.convert_language/1)
      ],
      episode_title: [
        ~x".//TVRProgram",
        value: ~x"./VersionableInfo/Version/EpisodeTitle/text()"S,
        language:
          ~x"./VersionableInfo/Version/EpisodeTitle/@LanguageCode"S
          |> transform_by(&Text.convert_language/1)
      ],
      content_desc: [
        ~x".//TVRProgram",
        value: ~x"./Description/TextDesc/text()"S,
        language:
          ~x"./Description/TextDesc/@LanguageCode"S |> transform_by(&Text.convert_language/1)
      ],
      series_desc: [
        ~x".//TVRProgram",
        value: ~x"./SeriesSeason/Description/TextDesc/text()"S,
        language:
          ~x"./SeriesSeason/Description/TextDesc/@LanguageCode"S
          |> transform_by(&Text.convert_language/1)
      ],
      category: ~x".//TVRProgram/ProgramData/Category/text()"S,
      url: ~x".//TVRBroadcast/BroadcastInformation/WebPage/@URL"S
    )
    |> process_items(tuple)
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items([], tuple), do: tuple

  defp process_items([item | items], tuple) do
    process_items(
      items,
      tuple
      |> NewBatch.add_airing(item |> process_airing())
    )
  end

  defp process_airing(item) do
    %{
      start_time: item[:start_time],
      end_time: item[:end_time],
      url: item[:url],
      titles:
        Text.convert_string(
          item[:content_title][:value],
          item[:content_title][:language],
          "content"
        ) ++
          Text.convert_string(
            item[:series_title][:value],
            item[:series_title][:language],
            "series"
          ),
      descriptions:
        Text.convert_string(
          item[:content_desc][:value],
          item[:content_desc][:language],
          "content"
        ) ++
          Text.convert_string(
            item[:series_desc][:value],
            item[:series_desc][:language],
            "series"
          ),
      subtitles:
        Text.convert_string(
          item[:episode_title][:value],
          item[:episode_title][:language],
          "content"
        )
    }
    |> parse_episode
    |> append_categories(
      Translation.translate_category(
        "Axess_category",
        try_to_split(
          item[:category],
          ","
        )
      )
    )
  end

  # TODO: Move over to StringMatcher

  # Grab episode data and add it to the map
  defp parse_episode(airing) do
    # GO THROUGH DESCS & UPDATE
    # GO THROUGH SUBTITLES & UPDATE
    airing
    |> parse_descriptions
    |> parse_subtitles
    |> parse_titles
  end

  # Parse and clean a subtitle and return a new updated variant
  defp parse_subtitles(airing) do
    case airing do
      %{subtitles: []} ->
        airing

      %{subtitles: subtitles} ->
        # Empty the array
        %{data: data, texts: texts} = TextParser.parse(subtitles, &regexp_subtitle/1)

        Map.put(airing, :subtitles, texts)
        |> TextParser.merge_with_lists(data)

      _ ->
        airing
    end
  end

  # Parse and clean a title and return a new updated variant
  defp parse_titles(airing) do
    case airing do
      %{titles: []} ->
        airing

      %{titles: titles} ->
        # Empty the array
        %{data: data, texts: texts} = TextParser.parse(titles, &regexp_subtitle/1)

        Map.put(airing, :titles, texts)
        |> TextParser.merge_with_lists(data)

      _ ->
        airing
    end
  end

  # Parse and clean a description and return a new updated variant
  defp parse_descriptions(airing) do
    case airing do
      %{descriptions: []} ->
        airing

      %{descriptions: descriptions} ->
        # Empty the array
        %{data: data, texts: texts} = TextParser.parse(descriptions, &regexp_description/1)

        Map.put(airing, :descriptions, texts)
        |> TextParser.merge_with_lists(data)

      _ ->
        airing
    end
  end

  # This regular expression is matching towards a splitted string
  # of a subtitle.
  defp regexp_subtitle([]), do: []

  defp regexp_subtitle([string | list]) do
    returned_data =
      if Regex.match?(~r/Del\s+(\d+)\s+av\s+(\d+)/i, string) do
        # Del x av x
        # * there might be more text after so we have to Text.norm
        # it. We also have to remove the single dot that join_text adds.

        %{"episode_num" => episode_num, "of_episodes" => of_episodes} =
          Regex.named_captures(
            ~r/Del\s+(?<episode_num>[0-9]+?)\s+av\s+(?<of_episodes>[0-9]+?)/i,
            string
          )

        {new_string, season_data} =
          String.replace(
            string,
            ~r/Del\s+(?<episode_num>[0-9]+?)\s+av\s+(?<of_episodes>[0-9]+?)/,
            ""
          )
          |> parse_season_regex()

        {
          new_string
          |> Text.norm()
          |> cleanup_text(),
          Map.merge(season_data, %{
            episode: String.to_integer(episode_num),
            of_episode: String.to_integer(of_episodes)
          })
        }
      else
        {cleanup_text(string), %{}}
      end

    [returned_data | regexp_subtitle(list)]
  end

  defp parse_season_regex(string) do
    # säsong 1
    if Regex.match?(~r/Säsong\s+(\d+)/iu, string) do
      %{"season" => season} =
        Regex.named_captures(
          ~r/Säsong\s+(?<season>[0-9]+?)/iu,
          string
        )

      {
        String.replace(
          string,
          ~r/Säsong\s+(?<season>[0-9]+?)/iu,
          ""
        )
        |> Text.norm(),
        %{season: String.to_integer(season)}
      }
    else
      {
        string,
        %{}
      }
    end
  end

  # This regular expression is matching towards splitted string
  # of a description.
  defp regexp_description([]), do: []

  defp regexp_description([string | list]) do
    returned_data =
      cond do
        # Parse episode and of_episode numbers in the format of:
        # Del 4 av 9.
        # ** The string is removed from the list
        Regex.match?(~r/Del\s+(?<episode_num>[0-9]+?)\s+av\s+(?<of_episodes>[0-9]+?)/i, string) ->
          %{"episode_num" => episode_num, "of_episodes" => of_episodes} =
            Regex.named_captures(
              ~r/Del\s+(?<episode_num>[0-9]+?)\s+av\s+(?<of_episodes>[0-9]+?)/i,
              string
            )

          {
            nil,
            %{
              episode: String.to_integer(episode_num),
              of_episode: String.to_integer(of_episodes)
            }
          }

        # Match original title in the format of:
        # Originaltitel: The Art of Germany: Peeling back the canvas.
        # ** The string is removed from the list
        Regex.match?(~r/^Originaltitel\: (.*?)\.$/, string) ->
          %{"original_title" => original_title} =
            Regex.named_captures(
              ~r/^Originaltitel: (?<original_title>.*?)\.$/i,
              string
            )

          {nil,
           %{
             titles: [
               %{
                 language: Text.convert_language(Paasaa.detect(original_title)),
                 type: "original",
                 value: Text.norm(original_title)
               }
             ]
           }}

        # Match production company (and year) in the format of:
        # Produktion: BBC 2010.
        # ** The string is removed from the list
        Regex.match?(~r/^Produktion\: (.*?)\.$/, string) ->
          {nil, %{}}

        true ->
          {string, %{}}
      end

    [returned_data | regexp_description(list)]
  end

  defp cleanup_text(""), do: nil
  defp cleanup_text(nil), do: nil

  defp cleanup_text(text) do
    text
    |> Okay.trim()
    |> Okay.replace(~r/^\:/, "")
    |> Okay.replace(~r/^\./, "")
    |> Okay.trim()
    |> Okay.replace(~r/\.$/, "")
    |> Okay.replace(~r/\-$/, "")
    |> Okay.replace(~r/^\-/, "")
    |> Okay.replace(~r/\-$/, "")
    |> Okay.trim()
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) do
    datetime_string
    |> DateTimeParser.parse_datetime!()
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, _channel) do
    import ExPrintf

    sprintf("https://www.axess.se/xml-tv-schedule.php?date=%s", [
      date
    ])
  end

  @doc """
  This is custom to this importer as you can't fetch days less than today.
  """
  @impl true
  def periods(%{amount: max_days}, _) do
    use Timex

    current_date = Timex.shift(Date.utc_today(), days: 0)

    Date.range(current_date, Date.add(current_date, max_days))
    |> Okay.map(&Timex.format!(&1, "%Y-%m-%d", :strftime))
    |> Okay.uniq()
  end
end
