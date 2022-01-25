defmodule Importer.Web.ORF do
  @moduledoc """
  Importer for ORF
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.Helper, as: ParserHelper
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

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
    |> process(batch)
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Vienna")
      |> NewBatch.start_date(batch |> NewBatch.date_from_batch_name(), "00:00")
    )
  end

  defp process_items({:error, reason}, _), do: {:error, reason}
  defp process_items(_, {:error, reason}), do: {:error, reason}

  defp process_items({:ok, []}, tuple), do: tuple

  defp process_items({:ok, [item | items]}, tuple) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.add_airing(item)
    )
  end

  defp process(body, batch) do
    body
    |> parse(encoding: 'latin1')
    ~>> xpath(
      ~x"//sendung"l,
      start_time: ~x".//zeit/text()"S,
      content_title: ~x".//titel/text()"S,
      content_subtitle: ~x".//subtitel/text()"So
    )
    |> Okay.map(&process_item(&1, batch))
    |> Okay.reject(&is_nil/1)
    |> ParserHelper.sort_by_start_time()
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  # TODO: Add qualifiers etc
  defp process_item(item, batch) do
    %{
      start_time: item[:start_time] |> parse_datetime(batch),
      titles:
        Text.convert_string(
          item[:content_title] |> Text.norm(),
          "de",
          "content"
        )
    }
  end

  defp parse_datetime(start_time, batch) do
    [_, date] = batch.name |> String.split("_")

    [hour, minute] = start_time |> String.split(":")

    Timex.parse!("#{date}", "%Y-%0m-%0d", :strftime)
    |> Timex.set(
      hour: hour |> String.to_integer(),
      minute: minute |> String.to_integer()
    )
  end

  @doc """
  HTTP client

  For ORF: Login first before fetching
  """
  @impl true
  def http_login(env, config, _folder) do
    import ExPrintf

    url =
      sprintf(
        "https://presse.orf.at/?login[action]=login&login[redirect]=&login[username]=%s&login[password]=%s",
        [
          config.username,
          config.password
        ]
      )

    env
    |> Shared.HttpClient.get(url)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, _config, channel) do
    import ExPrintf

    sprintf("https://presse.orf.at/download.php?sender=%s&date=%s", [
      channel.grabber_info,
      date |> String.replace("-", "")
    ])
  end
end
