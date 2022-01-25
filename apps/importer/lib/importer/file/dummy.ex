# TODO: Create

defmodule Importer.File.Dummy do
  use Importer.Base.File
  alias Importer.Helpers.NewBatch

  @moduledoc """
    Dummy Importer
  """

  @impl true
  def import_content(_channel, _file_name, _file) do
    NewBatch.dummy_batch()
  end
end
