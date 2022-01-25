defmodule Shared.HttpClient.Cookie do
  def parse(set_cookie_string) do
    [content | _attributes] = String.split(set_cookie_string, ~r/;\s*/)
    [key, value] = String.split(content, "=", parts: 2)
    # attributes = Enum.map(attributes, &parse_attribute/1) |> Enum.into(%{})
    # , attributes: attributes
    %{key: key, value: value}
  end

  defp parse_attribute("domain=" <> domain), do: {:domain, domain}
  defp parse_attribute("path=" <> path), do: {:path, path}
  defp parse_attribute("HttpOnly"), do: {:http_only, true}
  defp parse_attribute("secure"), do: {:secure, true}
  defp parse_attribute("max-age=" <> max_age), do: {:max_age, max_age}
  defp parse_attribute("expires=" <> expires), do: {:expires, expires}
  defp parse_attribute(extra), do: {:extra, extra}
end
