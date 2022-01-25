defmodule FileManager.Source.FTP do
  @moduledoc """
  Runs matches on incoming ftp files
  """

  alias Shared.Zip

  def process(%{"path" => file_path, "extension" => ".zip"}),
    do: unpack_zip(file_path)

  def process(%{"directory" => directory, "path" => file_path}) do
    # Do checks towards the ftp_rule db
    Database.Importer.get_all_ftp_rules()
    |> sort_rules(directory)
    |> match!(directory, file_path |> Path.basename())
    |> add?(file_path)
  end

  defp unpack_zip(file_path) do
    # Unzip into the dir
    _ = Zip.unzip(file_path, [{:cwd, file_path |> Path.dirname() |> to_charlist()}])

    # Remove zip
    File.rm(file_path)

    :ok
  end

  # Matches a list of rules to a channel
  defp match!([], _, _), do: {:error, "no matches"}

  defp match!([rule | rules], directory, file_name) do
    if cond_match?(rule.file_extension, file_name) &&
         cond_match?(rule.file_name, file_name) do
      {:ok, rule.channels}
    else
      match!(rules, directory, file_name)
    end
  end

  # Sort through the rules and only return the rules that match the directory
  defp sort_rules([], _), do: []

  defp sort_rules([rule | rules], directory) do
    if cond_match?(rule.directory, directory) do
      [rule | sort_rules(rules, directory)]
    else
      sort_rules(rules, directory)
    end
  end

  # Enqueues a background worker to *maybe* add a file to a channel
  defp add?({:error, message}, file_path), do: {:error, message, file_path}

  defp add?({:ok, channel}, file_path),
    do: {:ok, {channel, file_path}}

  # Return true otherwise it will fail instantly
  defp cond_match?(nil, _), do: true

  defp cond_match?(regex, value), do: regex |> Regex.match?(value)
end
