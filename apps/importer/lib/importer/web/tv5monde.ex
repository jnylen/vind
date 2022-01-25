defmodule Importer.Web.TV5Monde do
  @moduledoc """
  Importer for TV5Monde.
  """

  use Importer.Base.Periodic, type: "one"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text

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

  defp process(body, channel) do
    body
    |> Okay.map(&process_item(&1, channel))
    |> OK.wrap()
  end

  # TODO: Add description parsing

  defp process_item(item, channel) do
    %{
      start_time: item["b"] |> parse_datetime(),
      titles:
        Text.convert_string(
          item["t"] |> fix_title(),
          List.first(channel.schedule_languages),
          "content"
        )
    }
  end

  defp parse_datetime(%{"value" => value, "timezone" => timezone}) do
    value
    |> Timex.parse!("%Y-%0m-%0d %H:%M:%S", :strftime)
    |> Timex.to_datetime(timezone)
    |> Timex.Timezone.convert("UTC")
  end

  defp fix_title(string) do
    string
    |> String.replace("&#039;", "'")
    |> String.downcase()
    |> Text.title_case()
    |> String.replace(~r/tv5monde/i, "TV5Monde")
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(_date, config, channel) do
    import ExPrintf

    sprintf("%s/schedule-json-%s.json", [
      config.url_root,
      channel.grabber_info
    ])
  end
end
