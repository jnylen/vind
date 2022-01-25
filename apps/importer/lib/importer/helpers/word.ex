defmodule Importer.Helpers.Word do
  @moduledoc """
  A helper for parsing word files.
  """

  def parse(file_name) do
    # Read the doc file
    {html, _} = System.cmd("wvHtml", ["--charset=utf-8", file_name, "-"])

    html
  end

  def parse_docx(file_name) do
    {html, _} = System.cmd("npx", ["mammoth", "--output-format=html", file_name])

    html
  end
end
