defmodule Importer.Web.Kanal2 do
  @moduledoc """
  Importer for Kanal2.ee channels.
  """

  use Importer.Base.Periodic, type: "daily"
  use Importer.Helpers.Translation

  alias Importer.Helpers.NewBatch
  alias Importer.Helpers.Okay
  alias Importer.Helpers.Text
  alias Importer.Helpers.Translation

  require OK
  use OK.Pipe

  @doc """
  Function to handle inputted data from the Importer Base
  """
  @impl true
  def import_content(tuple, batch, _channel, %{body: body} = _data) do
    body
    |> process()
    |> process_items(
      tuple
      |> NewBatch.set_timezone("Europe/Tallinn")
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

  defp process(body) do
    body
    |> Jsonrs.decode()
    |> Okay.map(&process_item(&1))
    |> OK.wrap()
  end

  # TODO: Add qualifiers

  defp process_item(item) do
    %{
      start_time: item["datetime_start"] |> parse_datetime(),
      end_time: item["datetime_end"] |> parse_datetime(),
      titles:
        Text.convert_string(item["telecast"] |> Text.norm(), "et", "content") ++
          Text.convert_string(item["original_title"] |> Text.norm(), nil, "original"),
      subtitles: Text.convert_string(item["subtitle"] |> Text.norm(), "et", "content"),
      descriptions: Text.convert_string(item["description"] |> Text.norm(), "et", "content"),
      episode: item["episode_nr"] |> to_correct_no(),
      production_date: Text.year_to_date(item["creator_year"]),
      images:
        ([to_image_struct(item["images"], "landscape")] ++
           [to_image_struct(item["images"], "vertical")])
        |> Enum.reject(&is_nil/1),
      program_type: item["telecast_type"] |> Text.norm() |> program_type()
    }
    |> append_countries(
      Translation.translate_country(
        "Kanal2",
        item["creator_country"] |> String.split("/")
      )
    )
    |> add_credits(parse_credits(item["creator_actors"], "actor"))
    |> add_credits(parse_credits(item["creator_director"], "director"))
  end

  defp to_correct_no(nil), do: nil

  defp to_correct_no(str) when is_binary(str),
    do: String.split(",") |> List.first() |> Text.to_integer() |> to_correct_no

  defp to_correct_no(int) when is_integer(int) do
    if int === 0 do
      nil
    else
      int
    end
  end

  defp parse_datetime(datetime_string) do
    Timex.parse!(datetime_string, "{ISO:Extended}")
  end

  defp parse_credits("", _), do: []
  defp parse_credits(nil, _), do: []

  defp parse_credits(string, type) do
    (string || "")
    |> String.split(", ")
    |> Okay.map(fn person ->
      %{
        person: Text.norm(person),
        type: type
      }
    end)
    |> Okay.reject(&is_nil(&1.person))
  end

  # Add credits
  defp add_credits(%{} = airing, list) when is_list(list) do
    airing
    |> Map.put(:credits, (Map.get(airing, :credits) || []) ++ list)
  end

  @doc """
  Returns an url from the inputted string (mostly an date)
  """
  @impl true
  def object_to_url(date, config, channel) do
    import ExPrintf

    sprintf("%s/%s/json?start=%s&end=%s", [
      config.url_root,
      channel.grabber_info,
      date |> to_string(),
      date |> to_string()
    ])
  end

  defp to_image_struct(nil, _), do: nil
  defp to_image_struct("", _), do: nil
  defp to_image_struct([], _), do: nil

  defp to_image_struct(images, element) when is_map(images) do
    if string = Map.get(images, element) do
      %ImageManager.Image{
        source: string,
        type: "content"
      }
    end
  end

  defp to_image_struct(_, _), do: nil

  defp program_type(nil), do: "series"
  defp program_type(""), do: "series"

  defp program_type(type) do
    case type |> String.downcase() do
      "s" -> "series"
      "m" -> "movie"
      _ -> "series"
    end
  end
end
