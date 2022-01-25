defmodule ImageManager.Uploader.Helper do
  def file_extension("svg"), do: ".svg"
  def file_extension("jpeg"), do: ".jpg"
  def file_extension("png"), do: ".png"

  def content_type("svg"), do: "image/svg+xml"
  def content_type("jpeg"), do: "image/jpeg"
  def content_type("png"), do: "image/png"
end
