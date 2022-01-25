defmodule Database.Image do
  @moduledoc """
  The Image context.
  """

  alias Database.Image.File

  def find_image_by_source!(source) do
    Database.Repo.get_by(File, source: source)
  end
end
