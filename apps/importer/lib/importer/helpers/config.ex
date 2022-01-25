defmodule Importer.Helpers.Config do
  def get_channel(config, channel) do
    config
    |> Map.get(:channels)
    |> Enum.filter(fn item ->
      item.xmltv_id == channel
    end)
    |> get_one()
  end

  defp get_one([]), do: nil
  defp get_one([item]), do: item
end
