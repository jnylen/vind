defmodule Shared.File.Helper do
  @doc """
  Return an base16 of a string
  """
  def encode_string(string) do
    :crypto.hash(:sha256, string)
    |> Base.encode16()
  end

  @doc """
  Stream a file and return a checksum
  """
  def file_checksum(file_path) do
    file_path
    |> File.stream!([], 2048)
    |> Enum.reduce(:crypto.hash_init(:sha256), fn line, acc ->
      :crypto.hash_update(acc, line)
    end)
    |> :crypto.hash_final()
    |> Base.encode16()
  end
end
