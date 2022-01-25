defimpl Phoenix.HTML.Safe, for: Regex do
  def to_iodata(%Regex{} = regex), do: regex |> Regex.source()
end
