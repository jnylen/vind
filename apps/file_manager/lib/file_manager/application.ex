defmodule FileManager.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ftp_store = Application.get_env(:file_manager, :ftp_store)

    children = [
      FileManagerWeb.Endpoint,
      {Phoenix.PubSub, [name: FileManager.PubSub, adapter: Phoenix.PubSub.PG2]},
      {FileManager.Handler.FTP, dirs: [ftp_store]}
    ]

    opts = [strategy: :one_for_one, name: FileManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    FileManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
