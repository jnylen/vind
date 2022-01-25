defmodule Importer.Helpers.Job do
  @moduledoc """
  Helper for Jobs
  """

  alias Database.Importer

  def insert_or_update(type, name, attrs) do
    job = fetch_job!(type, name) || insert_job!(type, name)

    job
    |> Importer.update_job(attrs)
  end

  defp fetch_job!(type, name) do
    Importer.get_job_by_type_and_name!(type, name)
  end

  defp insert_job!(type, name) do
    {:ok, job} =
      %{
        type: type,
        name: name
      }
      |> Importer.create_job()

    job
  end
end
