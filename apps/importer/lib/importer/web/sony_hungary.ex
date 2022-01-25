defmodule Importer.Web.SonyHungary do
  @moduledoc """
  Importer for Sony Televisions Hungary
  """

  use Importer.Base.Periodic, type: "weekly"

  alias Importer.Helpers.NewBatch
  alias Importer.Parser.PublicSchedule, as: Parser

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base

  The data received from Axess is in latin1
  """
  @impl true
  def import_content(tuple, _batch, channel, %{body: body}) do
    body
    |> process(
      tuple
      |> NewBatch.set_timezone("UTC"),
      channel
    )
  end

  defp process(body, tuple, channel) do
    body
    |> Parser.parse()
    |> process_items(tuple, channel)
  end

  # TODO: Fix titles
  defp process_items({:ok, []}, tuple, _), do: tuple

  defp process_items({:ok, [item | items]}, tuple, channel) do
    process_items(
      {:ok, items},
      tuple
      |> NewBatch.start_date(item.start_time, "00:00")
      |> NewBatch.add_airing(
        item
        |> remove_titles()
        |> Parser.remove_custom_fields()
      ),
      channel
    )
  end

  defp process_items(_, _, _), do: {:error, "didn't get any airings from parser"}

  defp remove_titles(airing) do
    airing
    |> Map.put(
      :titles,
      airing
      |> Map.get(:titles, [])
      |> Enum.reject(&remove_title?/1)
    )
  end

  defp remove_title?(%{original_type: "content"}), do: true
  defp remove_title?(_), do: false

  @doc """
  HTTP client

  For axess: Login first before fetching
  """
  @impl true
  def http_login(env, config, _folder) do
    env
    |> Shared.HttpClient.get("https://www.sonypicturespress.hu/user/login")
    |> Shared.HttpClient.with_form_id(
      "user-login-form",
      %{
        "name" => config.username,
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

    min_date =
      date
      |> Timex.parse!("%Y-%W", :strftime)
      |> Timex.beginning_of_week(:mon)
      |> Timex.to_date()

    max_date =
      date
      |> Timex.parse!("%Y-%W", :strftime)
      |> Timex.end_of_week(:mon)
      |> Timex.to_date()

    # https://www.sonypicturespress.hu/schedules/exports/xml/public-schedule-4-2?broadcast_day%5Bmax%5D=2019-09-23&broadcast_day%5Bmin%5D=2019-09-23&channel_id=3050
    sprintf(
      "https://www.sonypicturespress.hu/schedules/exports/xml/public-schedule-4-2?broadcast_day[max]=%s&broadcast_day[min]=%s&channel_id=%s",
      [
        max_date |> to_string(),
        min_date |> to_string(),
        channel.grabber_info
      ]
    )
  end
end
