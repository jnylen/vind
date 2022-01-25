defmodule FileManagerWeb.Router do
  use FileManagerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FileManagerWeb do
    pipe_through :api

    post "/mailgun/webhook", WebhookController, :receive
  end
end
