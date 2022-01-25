defmodule Shared.HttpClient do
  @moduledoc """
  This is a remake of the old http client with cookie support.
  """

  alias Shared.HttpClient.Middleware.ContentCache, as: HTTPCache
  alias Shared.HttpClient.Middleware.ContentCache.Store.File, as: StoreFile

  @default_middlewares [
    Tesla.Middleware.KeepRequest,
    # Tesla.Middleware.FollowRedirects,
    Tesla.Middleware.FormUrlencoded,
    {HTTPCache, [store: StoreFile]}
    # Tesla.Middleware.JSON
  ]

  @doc """
  Handles http client inital things, like basic auth etc.
  """
  def init(opts \\ %{}) do
    opts
    |> set_headers()
    |> set_cookie_jar()
    |> set_basic_auth()
    |> finish_init()
  end

  defp user_agent do
    "Vind/#{Shared.version()} (http://xmltv.se)"
  end

  defp set_cookie_jar({%{cookie_jar: jar} = opts, results}) do
    jar =
      case jar do
        {:ok, jar} -> jar
        val -> val
      end

    {
      opts,
      results
      |> Map.put(:cookie_jar, jar)
    }
  end

  defp set_cookie_jar(val), do: val

  defp set_headers(%{headers: headers} = opts) do
    results =
      %{}
      |> Map.put(:headers, headers)

    {opts, results}
  end

  defp set_headers(opts), do: {opts, %{}}

  defp set_basic_auth({%{password: _pass} = opts, results}) do
    {opts,
     results
     |> Map.put(:basic_auth, %{
       username: opts[:username],
       password: opts[:password]
     })}
  end

  defp set_basic_auth(data), do: data

  defp finish_init({_, results}), do: results

  @doc """
  Return a tesla client
  """
  def client(init, middleware \\ @default_middlewares) do
    middleware
    |> add_cookie_jar(init)
    |> add_basic_auth(init)
    |> add_headers(init)
    |> Tesla.client({Tesla.Adapter.Hackney, [recv_timeout: 30_000]})
  end

  defp add_cookie_jar(middleware, %Tesla.Env{} = env) do
    middleware
    |> Enum.concat([
      {Shared.HttpClient.Middleware.CookieJar, [cookie_jar: Keyword.get(env.opts, :cookie_jar)]}
    ])
  end

  defp add_cookie_jar(middleware, %{cookie_jar: nil}), do: middleware

  defp add_cookie_jar(middleware, %{cookie_jar: jar}) do
    middleware
    |> Enum.concat([
      {Shared.HttpClient.Middleware.CookieJar, [cookie_jar: jar]}
    ])
  end

  defp add_cookie_jar(middleware, _), do: middleware

  defp add_basic_auth(middleware, %{basic_auth: %{username: username, password: password}}) do
    middleware
    |> Enum.concat([
      {Tesla.Middleware.BasicAuth, [username: username, password: password]}
    ])
  end

  defp add_basic_auth(middleware, _), do: middleware

  defp add_headers(middleware, %{headers: headers}) do
    middleware
    |> Enum.concat([
      {Tesla.Middleware.Headers, headers |> Enum.concat([{"user-agent", user_agent()}])}
    ])
  end

  defp add_headers(middleware, _) do
    middleware
    |> Enum.concat([{Tesla.Middleware.Headers, [{"user-agent", user_agent()}]}])
  end

  @doc """
  Get the url (often only the first url as this sets cookies etc)
  """
  def get(client, url, opts \\ %{})

  def get(%Tesla.Client{} = client, url, opts) do
    client
    |> Tesla.get(url, opts: cache_opts(opts))
    |> verbose()
  end

  def get({client, _}, url, opts) do
    client
    |> Tesla.get(url, opts: cache_opts(opts))
    |> verbose()
  end

  def get(map, url, opts) when is_map(map) do
    map
    |> client()
    |> Tesla.get(url, opts: cache_opts(opts))
    |> verbose()
  end

  @doc """
  With form name get inputs etc, add them to a query map and put the ones with the label to submit
  """
  def with_form_name({_, env}, name, own_values), do: with_form_name(env, name, own_values)

  def with_form_name(%Tesla.Env{__client__: client, body: body, url: url}, name, own_values) do
    case body
         |> find_form(%{name: name})
         |> put_own_values(own_values) do
      {:ok, form} ->
        {:ok, form |> Map.put(:client, client) |> Map.put(:url, url)}

      val ->
        val
    end
  end

  def with_form_id({_, env}, id, own_values), do: with_form_id(env, id, own_values)

  def with_form_id(%Tesla.Env{__client__: client, body: body, url: url}, id, own_values) do
    case body
         |> Shared.Utf8.fixer()
         |> find_form(%{id: id})
         |> put_own_values(own_values) do
      {:ok, form} ->
        {:ok, form |> Map.put(:client, client) |> Map.put(:url, url)}

      val ->
        val
    end
  end

  def with_form_action({_, env}, action, own_values),
    do: with_form_action(env, action, own_values)

  def with_form_action(%Tesla.Env{__client__: client, body: body, url: url}, action, own_values) do
    case body
         |> Shared.Utf8.fixer()
         |> find_form(%{action: action})
         |> put_own_values(own_values) do
      {:ok, form} ->
        {:ok, form |> Map.put(:client, client) |> Map.put(:url, url)}

      val ->
        val
    end
  end

  defp find_form(body, %{name: name}) do
    import Meeseeks.CSS

    forms =
      for form <- body |> Meeseeks.all(css("form")) do
        if Meeseeks.attr(form, "name") == name do
          # Match
          {_, inputs} = Meeseeks.all(form, css("input")) |> map_inputs()

          %{
            inputs: inputs,
            action: Meeseeks.attr(form, "action")
          }
        else
          nil
        end
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    if length(forms) == 1 do
      {:ok, forms |> List.first()}
    else
      {:error, "either no match or too many matches"}
    end
  end

  defp find_form(body, %{id: id}) do
    import Meeseeks.CSS

    forms =
      for form <- body |> Meeseeks.all(css("form")) do
        if Meeseeks.attr(form, "id") == id do
          # Match
          {_, inputs} = Meeseeks.all(form, css("input")) |> map_inputs()

          %{
            inputs: inputs,
            action: Meeseeks.attr(form, "action")
          }
        else
          nil
        end
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    if length(forms) == 1 do
      {:ok, forms |> List.first()}
    else
      {:error, "either no match or too many matches"}
    end
  end

  defp find_form(body, %{action: action}) do
    import Meeseeks.CSS

    forms =
      for form <- body |> Meeseeks.all(css("form")) do
        if Meeseeks.attr(form, "action") == action do
          # Match
          {_, inputs} = Meeseeks.all(form, css("input")) |> map_inputs()

          %{
            inputs: inputs,
            action: Meeseeks.attr(form, "action")
          }
        else
          nil
        end
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    if length(forms) == 1 do
      {:ok, forms |> List.first()}
    else
      {:error, "either no match or too many matches"}
    end
  end

  defp map_inputs(inputs) do
    inputs
    |> Enum.map_reduce(%{}, fn input, acc ->
      {[],
       acc
       |> Map.put_new(Meeseeks.attr(input, "name"), Meeseeks.attr(input, "value"))}
    end)
  end

  defp put_own_values({:ok, %{action: action, inputs: inputs}}, own_values) do
    {:ok,
     %{
       action: action,
       inputs: inputs |> put_values(own_values)
     }}
  end

  defp put_own_values(return, _), do: return

  defp put_values(map, values) do
    {_, val} =
      values
      |> Enum.map_reduce(map, fn {key, value}, acc ->
        {[], acc |> Map.put(key, value)}
      end)

    val
  end

  @doc """
  Post the url (often only the first url as this sets cookies etc)
  """
  def post({:error, val}, _), do: {:error, val}

  def post({:ok, %{client: client, action: action, inputs: inputs, url: url}}, opts) do
    client
    |> Tesla.post(merge_urls(url, action), inputs, opts: cache_opts(opts))
    |> verbose()
  end

  def post({client, _}, {:ok, %{action: action, inputs: inputs, url: url}}, opts) do
    client
    |> Tesla.post(merge_urls(url, action), inputs, opts: cache_opts(opts))
    |> verbose()
  end

  defp merge_urls(%{url: url}, action) do
    URI.merge(url, action)
    |> to_string()
  end

  defp merge_urls(url, action) do
    URI.merge(url, action)
    |> to_string()
  end

  def post(client, url, body, opts \\ %{})

  def post(%Tesla.Client{} = client, url, body, opts) do
    client
    |> Tesla.post(url, body, opts: cache_opts(opts))
    |> verbose()
  end

  def post({client, _}, url, body, opts) do
    client
    |> Tesla.post(url, body, opts: cache_opts(opts))
    |> verbose()
  end

  # Puts out logs to tell me if its updated or not.
  defp verbose({_, %Tesla.Env{} = env} = response) do
    require Logger

    _ =
      env
      |> Tesla.get_header("x-cache-status")
      |> case do
        "cached" -> Logger.info("Fetched #{env.url} from cache")
        "updated" -> Logger.info("Fetched and updated #{env.url} from server")
        "new" -> Logger.info("Fetched #{env.url} from server")
        "skipped" -> Logger.info("Fetched #{env.url} from server")
        _ -> nil
      end

    response
  end

  defp verbose(response), do: response

  defp cache_opts(%{file_name: file_name, folder_name: folder_name}) do
    [file_name: file_name, folder_name: folder_name]
  end

  defp cache_opts(_), do: []

  @doc """
  Checks if an tesla env is fresh (meaning new or updated) or cached
  """
  def fresh?(%Tesla.Env{} = env) do
    env
    |> Tesla.get_header("x-cache-status")
    |> case do
      "cached" -> false
      "updated" -> true
      "new" -> true
      "skipped" -> true
      _ -> false
    end
  end
end
