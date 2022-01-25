defmodule FileManager.WebhookTest do
  use FileManager.DataCase

  alias FileManager.Webhook

  describe "webhooks" do
    alias FileManager.Webhook.Webhooker

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def webhooker_fixture(attrs \\ %{}) do
      {:ok, webhooker} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Webhook.create_webhooker()

      webhooker
    end

    test "list_webhooks/0 returns all webhooks" do
      webhooker = webhooker_fixture()
      assert Webhook.list_webhooks() == [webhooker]
    end

    test "get_webhooker!/1 returns the webhooker with given id" do
      webhooker = webhooker_fixture()
      assert Webhook.get_webhooker!(webhooker.id) == webhooker
    end

    test "create_webhooker/1 with valid data creates a webhooker" do
      assert {:ok, %Webhooker{} = webhooker} = Webhook.create_webhooker(@valid_attrs)
    end

    test "create_webhooker/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Webhook.create_webhooker(@invalid_attrs)
    end

    test "update_webhooker/2 with valid data updates the webhooker" do
      webhooker = webhooker_fixture()
      assert {:ok, %Webhooker{} = webhooker} = Webhook.update_webhooker(webhooker, @update_attrs)
    end

    test "update_webhooker/2 with invalid data returns error changeset" do
      webhooker = webhooker_fixture()
      assert {:error, %Ecto.Changeset{}} = Webhook.update_webhooker(webhooker, @invalid_attrs)
      assert webhooker == Webhook.get_webhooker!(webhooker.id)
    end

    test "delete_webhooker/1 deletes the webhooker" do
      webhooker = webhooker_fixture()
      assert {:ok, %Webhooker{}} = Webhook.delete_webhooker(webhooker)
      assert_raise Ecto.NoResultsError, fn -> Webhook.get_webhooker!(webhooker.id) end
    end

    test "change_webhooker/1 returns a webhooker changeset" do
      webhooker = webhooker_fixture()
      assert %Ecto.Changeset{} = Webhook.change_webhooker(webhooker)
    end
  end
end
