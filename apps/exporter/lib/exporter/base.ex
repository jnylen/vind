defmodule Exporter.Base do
  @moduledoc """
  The exporter behaviour and base.
  """

  # @callback process(batch :: Map.t()) ::
  #            {:ok, Map.t()} | {:error, Map.t()} | {:error, String.t()}
  @callback export(batch :: List.t(), batch :: Map.t()) ::
              {:ok, Map.t()} | {:error, Map.t()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Exporter.Base

      def days, do: 22
      defoverridable days: 0

      @doc """
      Get the programs for the batch and run the export
      """
      def process(channel, exporter) do
        channel.id
        |> Database.Network.get_airings_by_channel_id_and_dates!(
          datetime_now() |> Timex.shift(days: -1),
          datetime_now() |> datetime_add(days())
        )
        |> process_export(channel, exporter)
      end

      defoverridable process: 2

      def process(channel, batch, exporter) do
        batch.id
        |> Database.Network.get_airings_by_batch_id!()
        |> process_export(channel, exporter)
      end

      defoverridable process: 3

      def process_channels(exporter) do
        Database.Network.Channel
        |> Database.Repo.all()
        |> Enum.sort_by(& &1.xmltv_id)
        |> export_channels()
        |> write_to_file(exporter)
      end

      defoverridable process_channels: 1

      def process_channels(group, exporter) do
        group
        |> Database.Network.get_channels_by_group!()
        |> Enum.sort_by(& &1.xmltv_id)
        |> export_channels()
        |> write_to_file(group, exporter)
      end

      defoverridable process_channels: 2

      defp process_export(airings, channel, exporter) do
        # Get a map range
        {_, days} =
          Date.range(
            Timex.now() |> Timex.shift(days: -1) |> Timex.to_date(),
            Timex.now() |> Timex.shift(days: 21) |> Timex.to_date()
          )
          |> Enum.map_reduce(%{}, fn date, acc ->
            {nil, acc |> Map.put_new(date, [])}
          end)

        {_, new_airings} =
          airings
          |> Database.Repo.preload(:image_files)
          |> Enum.map(&add_missing_end_time/1)
          |> Enum.map_reduce(days, fn airing, acc ->
            date = to_date(airing.start_time)

            if Map.has_key?(acc, date) do
              {nil, acc |> Map.put(date, Enum.concat(Map.get(acc, date), [airing]))}
            else
              {nil, acc}
            end
          end)

        new_airings
        |> Enum.into([])
        |> Enum.map(fn {date, airings} ->
          {:ok, content} = export(airings, channel)

          %{date: date, content: content}
        end)
        |> Enum.map(fn %{date: date, content: content} ->
          write_to_file(content, channel, date, exporter)
        end)
      end

      defp add_missing_end_time(%{end_time: nil} = airing) do
        new_end_time =
          Database.Network.next_airing_by_start(airing.channel_id, airing.start_time)
          |> try_to_get(:start_time)

        airing
        |> Map.put(:end_time, new_end_time)
      end

      defp add_missing_end_time(airing), do: airing

      defp to_date(start) do
        if start.hour < 4 do
          start
          |> Timex.shift(days: -1)
          |> DateTime.to_date()
        else
          start
          |> DateTime.to_date()
        end
      end

      defp try_to_get(nil, _), do: nil
      defp try_to_get(map, key), do: map |> Map.get(key)

      # Convert the dates to unixtimestamp to sort it
      defp get_date({date, _}), do: date |> Timex.to_datetime() |> DateTime.to_unix()
      defp get_date(_), do: nil

      # Add days that are missing to the array
      defp add_date?(_, []), do: []

      defp add_date?(existing_days, [date | dates]) do
        if Enum.member?(existing_days, date) do
          [add_date?(existing_days, dates)]
        else
          [date | add_date?(existing_days, dates)]
        end
      end

      # Datetime now and add
      defp datetime_now do
        DateTime.utc_now()
        |> Timex.shift(days: -1)
        |> Timex.set(hour: 0, minute: 0, second: 0)
      end

      defp datetime_add(datetime, days) do
        datetime
        |> Date.add(days)
        |> Timex.to_datetime()
        |> Timex.set(hour: 23, minute: 59, second: 59)
      end

      @doc """
      Export airings
      """
      def export(_airings, _channel), do: {:error, "export/2 not implemented"}

      def export_channels(_channels), do: {:error, "export_channels/1 not implemented"}

      defoverridable export: 2
      defoverridable export_channels: 1

      defp write_to_file({:ok, content}, exporter), do: write_to_file(content, exporter)

      defp write_to_file({:ok, content}, group, exporter),
        do: write_to_file(content, group, exporter)

      defp write_to_file({:ok, content}, channel, date, exporter),
        do: write_to_file(content, channel, date, exporter)

      defp write_to_file(content, exporter) do
        config =
          Application.get_env(:exporter, String.to_existing_atom(Macro.underscore(exporter)))
          |> Enum.into(%{})

        "#{config.path}/channels.#{config.ext}"
        |> compare_files(content)
      end

      defp write_to_file(content, group, exporter) do
        config =
          Application.get_env(:exporter, String.to_existing_atom(Macro.underscore(exporter)))
          |> Enum.into(%{})

        "#{config.path}/channels-#{group}.#{config.ext}"
        |> compare_files(content)
      end

      defp write_to_file(content, channel, date, exporter) do
        config =
          Application.get_env(:exporter, String.to_existing_atom(Macro.underscore(exporter)))
          |> Enum.into(%{})

        "#{config.path}/#{channel |> new_file_name?(config.ext)}_#{date}.#{config.ext}"
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

      defp new_file_name?(channel, "xml") do
        channel.new_xmltv_id || channel.xmltv_id
      end

      defp new_file_name?(channel, _) do
        channel.xmltv_id
      end
    end
  end
end
