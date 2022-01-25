defmodule Shared.HttpClient.Middleware.CookieJar do
  @behaviour Tesla.Middleware

  @impl true
  def call(env, next, opts) do
    env
    |> get_cookies_from_jar(opts)
    |> set_cookie_jar_opt(opts)
    |> Tesla.run(next)
    |> case do
      {:ok, env} ->
        {
          :ok,
          env
          |> add_cookies_from_jar(opts)
        }

      error ->
        error
    end
  end

  defp set_cookie_jar_opt({:error, _} = error, _opts), do: error

  defp set_cookie_jar_opt(env, opts) do
    Keyword.get(opts, :cookie_jar)
    |> case do
      nil ->
        env

      jar ->
        env
        |> Tesla.put_opt(:cookie_jar, jar)
    end
  end

  defp get_cookies_from_jar(env, opts) do
    Keyword.get(opts, :cookie_jar)
    |> case do
      nil ->
        env

      jar ->
        env
        |> put_cookies(jar)
    end
  end

  defp add_cookies_from_jar(env, opts) do
    Keyword.get(opts, :cookie_jar)
    |> case do
      nil ->
        env

      jar ->
        env
        |> save_cookies(jar)
    end
  end

  defp put_cookies(env, {:ok, jar}), do: put_cookies(env, jar)

  defp put_cookies(env, jar) do
    jar_cookies = CookieJar.label(jar)
    cookies = Tesla.get_header(env, "cookie") |> cookie_string()

    cookie_str =
      [cookies, jar_cookies] |> Enum.reject(&is_nil/1) |> Enum.join("; ") |> cookie_string()

    if is_nil(cookie_str) do
      env
    else
      env
      |> Tesla.put_header("cookie", cookie_str)
    end
  end

  defp save_cookies(env, {:ok, jar}), do: save_cookies(env, jar)

  defp save_cookies(env, jar) do
    cookies =
      env
      |> Tesla.get_headers("set-cookie")
      |> Enum.reduce(%{}, fn value, cookies ->
        [key_value_string | _rest] = String.split(value, "; ")
        [key, value] = String.split(key_value_string, "=", parts: 2)
        Map.put(cookies, key, value)
      end)

    CookieJar.pour(jar, cookies)

    env
    |> put_cookies(jar)
  end

  defp cookie_string(""), do: nil
  defp cookie_string(nil), do: nil
  defp cookie_string(string), do: string
end
