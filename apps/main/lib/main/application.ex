defmodule Main.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  import Supervisor.Spec

  use Application

  @env Mix.env()

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      Main.Endpoint,
      Main.Telemetry,
      {Phoenix.PubSub, [name: Main.PubSub, adapter: Phoenix.PubSub.PG2]}
    ]

    children_scheduler = [
      # Scheduler
      ## Daily
      %{
        id: "daily_importer",
        start:
          {SchedEx, :run_every,
           [Worker.Recurring.Importer, :enqueue, [%{"type" => "importer"}], "0 2 * * *"]}
      },
      %{
        id: "export_channels",
        start:
          {SchedEx, :run_every, [Worker.Recurring.ExportChannels, :enqueue, [%{}], "0 2 * * *"]}
      },
      %{
        id: "exporter",
        start: {SchedEx, :run_every, [Worker.Recurring.Exporter, :enqueue, [%{}], "*/30 * * * *"]}
      },
      %{
        id: "clean_up_old_files",
        start:
          {SchedEx, :run_every, [Worker.Recurring.CleanUpFiles, :enqueue, [%{}], "0 4 * * *"]}
      },

      ## Hourly
      %{
        id: "short_update_importer",
        start:
          {SchedEx, :run_every,
           [
             Worker.Recurring.Importer,
             :enqueue,
             [%{"type" => "short_update"}],
             "0 * * * *"
           ]}
      },
      %{
        id: "export_datalist",
        start:
          {SchedEx, :run_every, [Worker.Recurring.ExportDatalist, :enqueue, [%{}], "0 * * * *"]}
      },
      %{
        id: "generate_html",
        start:
          {SchedEx, :run_every, [Worker.Recurring.GenerateHTML, :enqueue, [%{}], "0 * * * *"]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Main.Supervisor]

    # if @env == :prod do
    Supervisor.start_link(children ++ children_scheduler, opts)
    # else
    #  Supervisor.start_link(children, opts)
    # end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Main.Endpoint.config_change(changed, removed)
    :ok
  end
end
