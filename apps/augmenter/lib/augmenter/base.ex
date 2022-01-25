defmodule Augmenter.Base do
  @moduledoc """
  This is the Augmenter Behaviour and base.

  Use this to build augmenters
  """

  @callback filter(airing :: Map.t(), rule :: Map.t()) ::
              {:ok, Map.t()} | {:error, Map.t()} | {:error, String.t()}
  @callback process(airing :: Map.t(), rule :: Map.t()) ::
              {:ok, Map.t()} | {:error, Map.t()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Augmenter.Base

      @doc """
      Remove every nil object after the filter has been run
      and return with :ok.
      """
      def process(airing, rule) do
        result =
          airing
          |> filter(rule)
          |> Enum.filter(fn {_, v} -> v != nil end)
          |> Enum.into(%{})

        {:ok, result}
      end

      defoverridable process: 2

      @doc """
      Default overrideable filter
      """
      def filter(_airing, _rule), do: {:error, "filter/2 not implemented"}

      defoverridable filter: 2

      defp get_metadata(_type, []), do: nil

      defp get_metadata(type, [%{type: type2, value: value} | metadatum]) do
        if type == type2 do
          value
        else
          get_metadata(type, metadatum)
        end
      end

      def merge_values(new_list, old_list) do
        new_list
        |> Enum.concat(
          old_list
          |> Enum.map(fn v ->
            v
            |> Map.from_struct()
            |> Map.delete(:id)
          end)
        )
      end
    end
  end
end
