defmodule Database.Type.Regex do
  @behaviour Ecto.Type
  def type, do: :string
  def embed_as(_mod, _format), do: :self
  def equal?(hi, hi), do: true
  def equal?(_, _), do: false

  def cast(regex) when is_bitstring(regex) do
    regex |> to_regex()
  end

  def cast(%Regex{} = regex), do: {:ok, regex}
  def cast(_), do: :error

  def load(data) when is_bitstring(data), do: data |> to_regex()

  defp to_regex(regex), do: regex |> Regex.compile("iu")

  defp from_regex(""), do: nil
  defp from_regex(nil), do: nil

  defp from_regex(%Regex{} = regex) when is_map(regex) do
    regex
    |> Regex.source()
  end

  def dump(%Regex{} = regex), do: {:ok, regex |> from_regex()}
  def dump(regex) when is_bitstring(regex), do: regex |> to_regex() |> from_regex()
  def dump(_), do: :error
end
