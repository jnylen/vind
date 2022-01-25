defmodule Importer.Web.RBB do
  @moduledoc """
  Importer for RBB.
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
      |> NewBatch.add_airing(item)
    )
  end

  # TODO: Add genre
  # TODO: Add credits
  defp process(body, channel) do
    body
    |> parse
    ~>> xpath(
      ~x"//SERVICE[@servicename='#{channel.grabber_info}']/SENDEABLAUF/SENDUNGSBLOCK/SENDEPLATZ"l,
      start_date: ~x".//ZEITINFORMATIONEN/VPS_LABEL/VPS_DATUM/text()"S,
      start_time: ~x".//ZEITINFORMATIONEN/VPS_LABEL/VPS_ZEIT/text()"S,
      content_title:
        ~x".//SENDUNGSINFORMATIONEN/TITELINFORMATIONEN/SENDUNGSTITELTEXT/text()"S
        |> transform_by(&Text.norm/1),
      content_description:
        ~x".//SENDUNGSINFORMATIONEN/INHALTSINFORMATIONEN/KURZINHALTSTEXT/text()"S
        |> transform_by(&Text.norm/1),
      episode_num:
        ~x".//SENDUNGSINFORMATIONEN/ERWEITERTE_TITELINFORMATIONEN/FOLGENINFORMATIONEN/FOLGENNUMMER/text()"Io,
      season_num:
        ~x".//SENDUNGSINFORMATIONEN/ERWEITERTE_TITELINFORMATIONEN/FOLGENINFORMATIONEN/STAFFEL/text()"Io
    )
    |> Okay.map(&process_item(&1))
    |> Okay.reject(&is_nil/1)
    |> OK.wrap()
  end

  # Go through the items and create the correct struct in order
  # to just add instantly.
  defp process_item(item) do
    %{
      start_time: parse_datetime(item.start_date, item.start_time),
      descriptions:
        Text.convert_string(
          item[:content_description],
          "de",
          "content"
        ),
      titles:
        Text.convert_string(
          item[:content_title],
          "de",
          "content"
        ),
      episode: item[:episode_num]
    }
  end

  # Parse an datetime in the ISO format to a UTC format
  # Standard format for XMLTV should be 2018-12-08 06:00:00
  defp parse_datetime(date, time) do
    "#{date}T#{time}"
    |> Timex.parse!("{ISO:Extended:Z}")
    |> Timex.to_datetime("Europe/Berlin")
    |> Timex.Timezone.convert("UTC")
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, _channel) do
    import ExPrintf

    [year, week] = date |> to_string() |> String.split("-")

    sprintf(
      "%s/%04d/%02d--programmwoche/xml-rbb.file.html/rbb-%02d.xml",
      [
        config.url_root,
        year |> String.to_integer(),
        week |> String.to_integer(),
        week |> String.to_integer()
      ]
    )
  end
end
