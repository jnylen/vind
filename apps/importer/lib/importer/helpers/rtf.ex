defmodule Importer.Helpers.RTF do
  @moduledoc """
  A helper for parsing RTF files.
  """

  def parse(file_name) do
    # Read the doc file
    {text, _} = System.cmd("unrtf", ["--text", file_name])

    text
    |> String.split("\n")
  end
end
