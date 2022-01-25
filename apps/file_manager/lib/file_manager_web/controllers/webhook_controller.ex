defmodule FileManagerWeb.WebhookController do
  use FileManagerWeb, :controller

  action_fallback(FileManagerWeb.FallbackController)

  @doc """
  Mailgun incoming webhook
  """
  def receive(conn, %{"message-url" => message_url} = _params) do
    Sentry.Context.add_breadcrumb(%{type: "mailgun", message_url: message_url})

    %{
      "type" => "mailgun",
      "message_url" => message_url
    }
    |> FileManager.Workers.Email.enqueue()
    |> case do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> render(:ok)

      :ok ->
        conn
        |> put_status(:ok)
        |> render(:ok)

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error)
    end
  end
end
