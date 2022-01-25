defmodule Worker.Recurring.ExportChannels do
  @moduledoc """
  Runs every day at 00:00 to export channels files
  """

  use TaskBunny.Job

  @exporters ["Xmltv", "NewHoneybee"]
  @countries [
    "Sweden",
    "Norway",
    "Finland",
    "Denmark",
    "Netherlands",
    "Germany",
    "Austria",
    "Switzerland",
    "Poland",
    "Croatia",
    "Hungary",
    "Latvia",
    "Lithuania",
    "Estonia",
    "Italy"
  ]

  @groups ["TV", "RADIO"] ++ @countries

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def perform(_ \\ nil) do
    # Export main files
    _ =
      @exporters
      |> Enum.map(&Exporter.export_channels/1)

    # Export groups
    @groups
    |> Enum.map(fn group ->
      @exporters
      |> Enum.map(&Exporter.export_channels(group, &1))
    end)

    :ok
  end
end
