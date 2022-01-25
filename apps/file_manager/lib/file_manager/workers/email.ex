defmodule FileManager.Workers.Email do
  @moduledoc """
  Runs match checking on a incoming email
  """
  use TaskBunny.Job
  require Logger

  alias FileManager.Uploader

  @impl true
  def timeout, do: 9_000_000_000

  @impl true
  def queue_key(payload) do
    key = payload |> Map.values() |> Enum.join("_")

    "filestore_email_#{key}"
  end

  @impl true
  def perform(%{"type" => "mailgun", "message_url" => message_url}) do
    results = message_url
    |> Uploader.incoming("email")

    if results == :ok || (is_list(results) && Enum.member?(results, :ok)) do
      :ok
    else
      {:error, "no OK files in returned value"}
    end
  end
end
