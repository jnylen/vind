defmodule FileManagerWeb.WebhookerControllerTest do
  use FileManagerWeb.ConnCase

  alias FileManager.Webhook
  alias FileManager.Webhook.Webhooker

  @create_attrs %{

  }
  @update_attrs %{

  }
  @invalid_attrs %{}

  def fixture(:webhooker) do
    {:ok, webhooker} = Webhook.create_webhooker(@create_attrs)
    webhooker
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all webhooks", %{conn: conn} do
      conn = get(conn, Routes.webhooker_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create webhooker" do
    test "renders webhooker when data is valid", %{conn: conn} do
      conn = post(conn, Routes.webhooker_path(conn, :create), webhooker: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.webhooker_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.webhooker_path(conn, :create), webhooker: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update webhooker" do
    setup [:create_webhooker]

    test "renders webhooker when data is valid", %{conn: conn, webhooker: %Webhooker{id: id} = webhooker} do
      conn = put(conn, Routes.webhooker_path(conn, :update, webhooker), webhooker: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.webhooker_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, webhooker: webhooker} do
      conn = put(conn, Routes.webhooker_path(conn, :update, webhooker), webhooker: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete webhooker" do
    setup [:create_webhooker]

    test "deletes chosen webhooker", %{conn: conn, webhooker: webhooker} do
      conn = delete(conn, Routes.webhooker_path(conn, :delete, webhooker))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.webhooker_path(conn, :show, webhooker))
      end
    end
  end

  defp create_webhooker(_) do
    webhooker = fixture(:webhooker)
    {:ok, webhooker: webhooker}
  end
end
