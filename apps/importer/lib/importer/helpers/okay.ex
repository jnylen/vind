defmodule Importer.Helpers.Okay do
  @moduledoc false

  @doc """
  Proxy to `Enum.reject`
  """
  def reject({:ok, value}, func) when is_function(func), do: Enum.reject(value, func)
  def reject({:error, reason}, _func), do: {:error, reason}
  def reject(value, func) when is_function(func), do: Enum.reject(value, func)

  @doc """
  Proxy to `Enum.flat_map`
  """
  def flat_map({:ok, value}, func) when is_function(func), do: Enum.flat_map(value, func)
  def flat_map({:error, reason}, _func), do: {:error, reason}
  def flat_map(value, func) when is_function(func), do: Enum.flat_map(value, func)

  @doc """
  Proxy to `Enum.map`
  """
  def map({:ok, value}, func) when is_function(func), do: Enum.map(value, func)
  def map({:error, reason}, _func), do: {:error, reason}
  def map(value, func) when is_function(func), do: Enum.map(value, func)

  @doc """
  Proxy to `Enum.map_reduce`
  """
  def map_reduce({:ok, value}, acc, func) when is_function(func),
    do: Enum.map_reduce(value, acc, func)

  def map_reduce({:error, reason}, _acc, _func), do: {:error, reason}
  def map_reduce(value, acc, func) when is_function(func), do: Enum.map_reduce(value, acc, func)

  @doc """
  Proxy to `Enum.sort`
  """
  def sort({:ok, value}), do: Enum.sort(value)
  def sort({:error, reason}), do: {:error, reason}
  def sort(value), do: Enum.sort(value)

  @doc """
  Proxy to `Enum.sort`
  """
  def sort({:ok, value}, func) when is_function(func), do: Enum.sort(value, func)
  def sort({:error, reason}, _func), do: {:error, reason}
  def sort(value, func) when is_function(func), do: Enum.sort(value, func)

  @doc """
  Proxy to `Enum.sort_by`
  """
  def sort_by(value, func, sorter \\ &<=/2)

  def sort_by({:ok, value}, func, sorter) when is_function(func),
    do: Enum.sort_by(value, func, sorter)

  def sort_by({:error, reason}, _func, _sorter), do: {:error, reason}

  def sort_by(value, func, sorter) when is_function(func),
    do: Enum.sort_by(value, func, sorter)

  @doc """
  Proxy to `Enum.filter`
  """

  def filter({:ok, value}, func) when is_function(func),
    do: Enum.filter(value, func)

  def filter({:error, reason}, _func), do: {:error, reason}

  def filter(value, func) when is_function(func),
    do: Enum.filter(value, func)

  @doc """
  Proxy to `List.flatten`
  """
  def flatten({:ok, value}) when is_list(value), do: List.flatten(value)
  def flatten({:error, reason}), do: {:error, reason}
  def flatten(value) when is_list(value), do: List.flatten(value)
  def flatten(_), do: {:error, "not a list"}

  @doc """
  Proxy to `Enum.join`
  """
  def join({:ok, value}, pattern), do: Enum.join(value, pattern)
  def join({:error, reason}, _pattern), do: {:error, reason}
  def join(value, pattern), do: Enum.join(value, pattern)

  @doc """
  Proxy to `Enum.to_list`
  """
  def to_list({:ok, value}), do: Enum.to_list(value)
  def to_list({:error, reason}), do: {:error, reason}
  def to_list(value), do: Enum.to_list(value)

  @doc """
  Proxy to `Enum.uniq`
  """
  def uniq({:ok, value}), do: Enum.uniq(value)
  def uniq({:error, reason}), do: {:error, reason}
  def uniq(value), do: Enum.uniq(value)

  @doc """
  Proxy to `Map.get`
  """
  def get(value, key, default \\ nil)

  def get({:ok, value}, key, default), do: Map.get(value, key, default)
  def get({:error, reason}, _, _), do: {:error, reason}
  def get(value, key, default), do: Map.get(value, key, default)

  @doc """
  Proxy to `List.first`
  """
  def first({:ok, value}), do: List.first(value)
  def first({:error, reason}), do: {:error, reason}
  def first(value), do: List.first(value)

  @doc """
  Proxy to `to_string`
  """
  def to_string({:ok, value}), do: Kernel.to_string(value)
  def to_string({:error, reason}), do: {:error, reason}
  def to_string(value), do: Kernel.to_string(value)

  @doc """
  Proxy to `String.trim`
  """
  def trim(nil), do: nil
  def trim({:ok, value}), do: String.trim(value)
  def trim({:error, reason}), do: {:error, reason}
  def trim(value), do: String.trim(value)

  @doc """
  Proxy to `String.replace`
  """
  def replace(nil, _, _), do: nil
  def replace({:ok, value}, replace, with_value), do: String.replace(value, replace, with_value)
  def replace({:error, reason}, _, _), do: {:error, reason}
  def replace(value, replace, with_value), do: String.replace(value, replace, with_value)

  @doc """
  Proxy to `Enum.concat`
  """
  def concat(value_1, value_2) do
    if is_ok?(value_1) && is_ok?(value_2) do
      Enum.concat(to_value(value_1), to_value(value_2))
    else
      {:error, "one of the values is a :ok tuple"}
    end
  end

  # Converts tuples to values
  defp to_value({:ok, value}), do: value
  defp to_value({:error, reason}), do: {:error, reason}
  defp to_value(value), do: value

  # Is a tuple?
  defp is_ok?({:ok, _}), do: true
  defp is_ok?({:error, _}), do: false
  defp is_ok?(_), do: true
end
