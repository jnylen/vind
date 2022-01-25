defmodule Worker.Recurring.Exporter do
  @moduledoc """
  Runs every day at 00:00 to export data for updated and +1 day of data.
  """

  use TaskBunny.Job

  @impl true
  def timeout, do: 2_400_000

  @impl true
  def perform(_ \\ nil) do
    channels =
      Database.Network.Channel
      |> Database.Repo.all()

    # Each channel
    channels
    |> Enum.map(fn channel ->
      Worker.Exporter.enqueue(%{"channel" => channel.xmltv_id})
    end)

    :ok
  end
end
