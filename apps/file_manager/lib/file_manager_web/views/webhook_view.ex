defmodule FileManagerWeb.WebhookView do
  use FileManagerWeb, :view

  def render("ok.json", _) do
    %{status: "ok"}
  end

  def render("rejected.json", _) do
    %{status: "rejected"}
  end

  def render("error.json", _) do
    %{status: "error"}
  end
end
