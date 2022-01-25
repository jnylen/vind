defmodule Importer.Web.ZDF do
  @moduledoc """
  Importer for ZDF.
  """

  use Importer.Base.Periodic, type: "weekly"
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
  def import_content(tuple, _batch, channel, %{body: body} = _data) do
    body
    |> process(channel)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Berlin")
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

  def process(body, channel) do
    body
    |> parse
    ~>> xpath(
      ~x"//sendung"l,
      start_time:
        ~x".//ausstrahlung/startzeit/text()"S
        |> transform_by(&parse_datetime/1),
      end_time:
        ~x".//ausstrahlung/biszeit/text()"S
        |> transform_by(&parse_datetime/1),
      content_title: ~x".//programm//sendetitel/text()"S |> transform_by(&Text.norm/1),
      original_title: ~x".//programm//originaltitel/text()"S |> transform_by(&Text.norm/1),
      content_subtitle: ~x".//programm//folgentitel/text()"S |> transform_by(&Text.norm/1),
      subtitles: ~x".//programm//untertitel/text()"S |> transform_by(&Text.norm/1),
      genre: ~x".//programm//progart/text()"S |> transform_by(&Text.norm/1),
      category: ~x".//programm//kategorie/text()"S |> transform_by(&Text.norm/1),
      production_countries: ~x".//programm//land/@kfz"lSo,
      production_year: ~x".//programm//jahr/text()"Io,
      directors: ~x".//programm//regie/text()"S |> transform_by(&Text.norm/1),
      content_description:
        ~x".//programm//programmtext//kurztext/text()"S |> transform_by(&Text.norm/1),
      episode_no: ~x".//programm//folgenr/text()"Io,
      attributes: ~x".//ausstrahlung/attribute/text()"S |> transform_by(&split_attributes/1),
      cast: [
        ~x".//besetzung/darsteller"l,
        person: ~x"./text()"S |> transform_by(&Text.norm/1),
        role: ~x"./@rolle"S |> transform_by(&Text.norm/1)
      ],
      images: [
        ~x"//urlbild[@layout='normal']"l,
        source: ~x"./text()"So
      ]
    )
    |> Okay.map(&process_item(&1, channel))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  defp process_item(item, _channel) do
    %{
      start_time: item[:start_time],
      end_time: item[:end_time],
      titles: Text.convert_string(item[:content_title], "de", "content"),
      descriptions: Text.convert_string(item[:content_description], "de", "content"),
      episode: item[:episode_no],
      production_date: Text.year_to_date(item[:production_year]),
      images:
        Enum.map(item[:images], fn data ->
          struct(ImageManager.Image, Map.put(data, :type, "content"))
        end)
    }
  end

  @doc """
  Temp client
  """
  @impl true
  def http_login(env, config, _folder) do
    env
    |> Shared.HttpClient.get("https://presseportal.zdf.de/start/")
    |> Shared.HttpClient.with_form_action(
      "/start/",
      %{
        "user" => config.username,
        "pass" => config.password
      }
    )
    |> Shared.HttpClient.post([])
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    [_, week] = date |> String.split("-")

    start_date =
      date
      |> Timex.parse!("%Y-%W", :strftime)
      |> Timex.beginning_of_week(:sun)

    last_date = start_date |> Timex.end_of_week(:sun)

    # https://presseportal.zdf.de/programmwochen/programmwoche/47/zdf/14.11.2015/20.11.2015/bc/showDownloads//xml/langfassung/
    sprintf(
      "https://presseportal.zdf.de/programmwochen/programmwoche/%s/%s/%s/%s/bc/showDownloads//xml/langfassung/",
      [
        week,
        channel.grabber_info,
        start_date |> NaiveDateTime.to_date() |> to_string(),
        last_date |> NaiveDateTime.to_date() |> to_string()
      ]
    )
  end

  defp parse_datetime(datetime_string) do
    datetime_string
    |> Timex.parse!("{YYYY}.{0M}.{D}T{h24}:{m}:{s}")
  end

  defp split_attributes(string) do
    string
    |> String.replace("&", "")
    |> String.replace(";", "")
    |> String.split(" ")
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  This is custom to this importer as you can't fetch days less than today.
  """
  @impl true
  def periods(%{amount: max_weeks}, _) do
    use Timex

    current_date = Date.utc_today() |> Timex.beginning_of_week()
    wanted_date = Timex.shift(current_date, weeks: max_weeks) |> Timex.end_of_week()

    periods =
      Timex.Interval.new(
        from: current_date,
        until: wanted_date,
        right_open: true,
        left_open: false
      )
      |> Interval.with_step(days: 7)
      |> Enum.map(&Timex.format!(&1, "%Y-%U", :strftime))
      |> Enum.uniq()

    if Timex.is_leap?(current_date.year) do
      periods
      |> Enum.concat(["#{current_date.year}-53"])
      |> Enum.sort()
    else
      periods
    end
  end
end
