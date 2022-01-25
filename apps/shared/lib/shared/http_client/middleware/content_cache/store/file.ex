defmodule Shared.HttpClient.Middleware.ContentCache.Store.File do
  @moduledoc """
  Filestorer for files.
  """

  @behaviour Shared.HttpClient.Middleware.ContentCache.Store

  def get(key) do
    case File.exists?(key) do
      true ->
        case decode(File.read!(key)) do
          nil -> :not_found
          data -> {:ok, data}
        end

      _ ->
        :not_found
    end
  end

  def put(key, data) do
    File.write!(key, encode(data))
  end

  def delete(key) do
    File.rm!(key)
  end

  defp encode(data), do: :erlang.term_to_binary(data)
  defp decode(nil), do: nil
  defp decode(bin), do: :erlang.binary_to_term(bin, [:safe])
end
