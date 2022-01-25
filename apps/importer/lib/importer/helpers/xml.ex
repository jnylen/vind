defmodule Importer.Helpers.Xml do
  @moduledoc """
  XML Helpers.

  We need to catch errors from xmerl because it doesn't return tuples.
  """

  @spec parse(any) :: {:error, <<_::144>>} | {:ok, any}
  def parse({:ok, data}), do: parse(data)
  def parse({:error, reason}), do: {:error, reason}

  def parse(data) do
    data
    |> SweetXml.parse()
    |> OK.wrap()
  rescue
    _ ->
      {:error, "couldn't parse XML"}
  catch
    :exit, _ -> {:error, "unknown crash"}
  end

  def parse(data, opts) do
    data
    |> SweetXml.parse(opts)
    |> OK.wrap()
  rescue
    _ ->
      {:error, "couldn't parse XML"}
  catch
    :exit, _ -> {:error, "unknown crash"}
  end
end
