defmodule Worker.Recurring.GenerateHTML do
  @moduledoc """
  Generate HTML statuses
  """

  @empty_file_size 200

  use TaskBunny.Job

  alias Importer.Helpers.Okay

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def queue_key(_), do: "recurring_generate_html"

  @impl true
  def perform(_ \\ nil) do
    config = Application.get_env(:exporter, :xmltv) |> Enum.into(%{})

    ### 00index.html
    ## While this is XMLTV, we want to show the status for all files
    ## and non-premium only output -1 + 4 days of data
    {days, channels} = file_list("premium_xmltv")

    html =
      Phoenix.View.render(Main.ExportView, "index.html", %{
        dates:
          days
          |> Enum.sort_by(fn i ->
            {i.year, i.month, i.day}
          end),
        channels:
          channels
          |> Enum.sort_by(fn {xmltv_id, _} ->
            xmltv_id
          end)
      })
      |> Phoenix.HTML.safe_to_string()

    File.write!(Path.join(config.path, "00index.html"), html)

    ### 00channels.html
    all_channels =
      Database.Network.Channel
      |> Database.Repo.all()
      |> Enum.sort_by(fn channel -> List.first(channel.display_names).value end)

    channels_html =
      Phoenix.View.render(Main.ExportView, "channels.html", %{
        channels: all_channels
      })
      |> Phoenix.HTML.safe_to_string()

    File.write!(Path.join(config.path, "00channels.html"), channels_html)
    File.write!(Path.join(config.path, "channels.html"), channels_html)

    :ok
  end

  def file_list("premium_xmltv") do
    config = Application.get_env(:exporter, :premium_xmltv) |> Enum.into(%{})

    {_, {days, channels}} =
      config.path
      |> Shared.System.List.files(["-name", "*_*.xml"])
      |> Okay.map_reduce({[], %{}}, fn file, {days, channel} = acc ->
        file["file_name"]
        |> String.split("_")
        |> case do
          [xmltv, date] ->
            {
              nil,
              {
                Enum.concat(days, [date |> String.replace(".xml", "") |> Date.from_iso8601!()])
                |> Enum.uniq(),
                channel |> put_date(file, xmltv, date |> String.replace(".xml", ""))
              }
            }

          _ ->
            {nil, acc}
        end
      end)

    {days, channels}
  end

  defp put_date(channels, file, xmltv_id, date) do
    channels
    |> Map.put(
      xmltv_id,
      %{
        xmltv_id: xmltv_id,
        days:
          Map.put(
            Map.get(Map.get(channels, xmltv_id, %{}), :days, %{}),
            date,
            file["file_size"] |> file_sizer()
          )
      }
    )
    |> Enum.sort_by(fn {xmltv_id, _} -> xmltv_id end)
    |> Enum.into(%{})
  end

  defp file_sizer(file_size) do
    file_size > @empty_file_size
  end
end
