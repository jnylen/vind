defmodule Shared.HttpClient.Middleware.ContentCache.Storage do
  @moduledoc """
  Storage base
  """
  def get(store, req) do
    case store.get(key(req)) do
      :not_found ->
        :not_found

      {:ok, {status, res_headers, body, _orig_req_headers}} ->
        {:ok, %{req | status: status, headers: res_headers, body: body}}
    end
  end

  def put(store, req, res) do
    store.put(key(res), entry(req, res))
  end

  def delete(store, req) do
    # check if there is stored vary for this URL
    case store.get(key(req)) do
      {:ok, [_ | _]} -> store.delete(key(req))
      _ -> store.delete(key(req))
    end
  end

  defp entry(req, res) do
    {res.status, res.headers, res.body, req.headers}
  end

  # defp entry(req, res), do: {res.status, res.headers, res.body, req.headers}

  defp key(%{opts: options} = env) when is_list(options),
    do: options |> Enum.into(%{}) |> key_opts(env)

  defp key_opts(%{file_name: file_name, folder_name: folder_name}, _),
    do: Path.join(folder_name, file_name)

  defp key_opts(%{folder_name: folder_name}, env), do: Path.join(folder_name, key_opts(nil, env))

  defp key_opts(_, %{url: url, query: query}), do: encode_key([Tesla.build_url(url, query)])

  defp encode_key(iodata), do: :crypto.hash(:sha256, iodata) |> Base.encode16()
end
