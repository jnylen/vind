defmodule Augmenter.Metagraph.Client do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, Application.get_env(:augmenter, :metagraph_url))

  plug(Tesla.Middleware.Headers, [
    {"authorization", "Bearer " <> Application.get_env(:augmenter, :metagraph_token)}
  ])

  plug(Tesla.Middleware.JSON, engine: Jsonrs)
  # plug(Tesla.Middleware.Logger)

  def one(uid) do
    get("/api/item/#{uid}")
    |> case do
      {:ok, %{body: %{"item" => value}}} ->
        value

      _ ->
        nil
    end
  end

  def find(field, value) do
    get("/api/query?field=#{field}&value=#{value}")
    |> case do
      {:ok, %{body: %{"uids" => values}}} ->
        values
        |> List.first()

      _ ->
        nil
    end
  end

  def search(value, type) do
    "/api/search?query=#{value}&filters=type = #{type}"
    |> URI.encode()
    |> get()
    |> case do
      {:ok, %{body: %{"items" => values}}} ->
        values

      _ ->
        []
    end
  end
end
