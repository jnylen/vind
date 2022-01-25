defmodule Importer.Helpers.Image do
  @moduledoc """
  Module for Image specific content
  """

  @doc """
  Converts an url with options for author etc.
  """
  def convert_string(url, opts \\ %{})
  def convert_string(nil, _), do: []

  def convert_string(url, opts) do
    [
      Map.merge(opts, %{
        url: url,
        source: opts[:source]
      })
    ]
  end

  def convert_string("", _, _), do: []
end
