defmodule Shared.ContentCache do
  def config do
    config =
      Application.get_env(:file_manager, :content_cache) ||
        Application.get_env(:importer, :content_cache)

    config
  end

  def folder do
    config()
  end

  def delete_files(grabber_name) do
    [config(), grabber_name |> to_string()]
    |> Path.join()
    |> File.rm_rf()
  end
end
