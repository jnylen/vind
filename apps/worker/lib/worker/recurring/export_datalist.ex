defmodule Worker.Recurring.ExportDatalist do
  @moduledoc """
  Exports a datalist
  """

  use TaskBunny.Job

  alias Importer.Helpers.Okay
  alias XMLTV.Datalist

  # , "premium_xmltv"
  @exporters ["xmltv", "new_honeybee"]

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def queue_key(_), do: "recurring_export_datalist"

  @impl true
  def perform(_ \\ nil) do
    @exporters
    |> Enum.map(&export_datalist/1)

    :ok
  end

  defp export_datalist("new_honeybee") do
    config = Application.get_env(:exporter, :new_honeybee) |> Enum.into(%{})

    # Get all channels
    channels = Database.Network.Channel |> Database.Repo.all()

    # Get all files with last modified and map em
    {_, files} =
      config.path
      |> Shared.System.List.files(["-name", "*_*.json"])
      |> Okay.map(&map_file(&1, config))
      |> Enum.map_reduce(%{}, fn file, acc ->
        {
          file,
          acc
          |> Map.put(
            file.channel,
            Map.get(acc, file.channel, [])
            |> Enum.concat([file |> Map.delete(:channel)])
            |> Enum.sort_by(& &1.date)
          )
        }
      end)

    channels
    |> Enum.sort_by(& &1.xmltv_id)
    |> Enum.map(&get_files(&1, files, "new_honeybee"))
    |> into_old_honeybee()
    |> write_to_file(:new_honeybee)
  end

  defp export_datalist("xmltv") do
    config = Application.get_env(:exporter, :xmltv) |> Enum.into(%{})

    # Get all channels
    channels = Database.Network.Channel |> Database.Repo.all()

    # Get all files with last modified and map em
    {_, files} =
      config.path
      |> Shared.System.List.files(["-name", "*_*.xml"])
      |> Okay.map(&map_file(&1, config))
      |> Enum.map_reduce(%{}, fn file, acc ->
        {
          file,
          acc
          |> Map.put(
            file.channel,
            Map.get(acc, file.channel, [])
            |> Enum.concat([file |> Map.delete(:channel)])
            |> Enum.sort_by(fn f ->
              {f.date.year, f.date.month, f.date.day}
            end)
          )
        }
      end)

    channels
    |> Enum.sort_by(&new_xmltv_id?(&1, "xmltv"))
    |> Enum.map(&get_files(&1, files, "xmltv"))
    |> XMLTV.as_string(%{
      generator_name: "Vind",
      generator_url: "https://xmltv.se"
    })
    |> write_to_file(:xmltv)
  end

  defp map_file(%{"file_name" => file_name, "last_modified" => last_modified}, _) do
    [channel, date] =
      String.split(
        file_name
        |> String.replace(~r/\.gz$/i, "")
        |> String.replace(~r/\.xml$/i, "")
        |> String.replace(~r/\.json$/i, "")
        |> String.replace(~r/\.js$/i, ""),
        "_"
      )

    %{
      channel: channel,
      date: date |> Date.from_iso8601!(),
      last_modified: last_modified
    }
  end

  defp get_files(%{display_names: channel_names} = channel, files, type) do
    data_for = files |> Map.get(new_xmltv_id?(channel, type), [])

    %Datalist{
      channel_id: new_xmltv_id?(channel, type),
      channel_names: channel_names,
      base_url: ["http://xmltv.xmltv.se", "https://xmltv.xmltv.se"],
      data_for: data_for
    }
  end

  defp into_old_honeybee(datalist) do
    %{
      "jsontv" => %{
        "channels" => datalist |> from_datalist() |> List.flatten() |> Enum.reverse()
      }
    }
    |> Jsonrs.encode!()
    |> OK.wrap()
  end

  defp from_datalist([]), do: []

  defp from_datalist([item | items]) do
    [
      %{
        "channel" => item.channel_id,
        "days" =>
          item.data_for
          |> Enum.map(fn day ->
            day
            |> Map.put("lastmodified", Map.get(day, :last_modified))
            |> Map.delete(:last_modified)
            |> Map.delete(:channel)
          end)
      }
      | from_datalist(items)
    ]
  end

  defp write_to_file({:ok, content}, exporter) do
    config =
      Application.get_env(:exporter, exporter)
      |> Enum.into(%{})

    "#{config.path}/datalist.#{config.ext}"
    |> compare_files(content)
  end

  defp compare_files(file_path, content) do
    if File.exists?(file_path) do
      current_file = file_path |> File.read!() |> encode_string()
      new_content = content |> encode_string()

      # Updated content
      if current_file != new_content do
        file_path
        |> write_file(content)
      end
    else
      file_path
      |> write_file(content)
    end
  end

  defp write_file(file_path, content) do
    require Logger

    Logger.debug("Writing: #{file_path}")
    File.write(file_path, content)

    Logger.debug("Writing: #{file_path}.gz")

    File.write("#{file_path}.gz", content, [
      :compressed
    ])
  end

  defp encode_string(body) do
    :crypto.hash(:sha256, body)
    |> Base.encode16()
  end

  defp new_xmltv_id?(channel, "xmltv") do
    channel.new_xmltv_id || channel.xmltv_id
  end

  defp new_xmltv_id?(channel, _), do: channel.xmltv_id
end
