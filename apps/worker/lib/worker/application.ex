defmodule Worker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  @env Mix.env()

  def start(_type, _args) do
    children = []

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Worker.Supervisor]

    if @env == :prod do
      Supervisor.start_link(children, opts)
    else
      Supervisor.start_link([], opts)
    end
  end
end
