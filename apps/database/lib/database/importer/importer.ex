defmodule Database.Importer do
  @moduledoc """
  The Importer context.
  """

  # require Durango
  alias Database.Uploader.File, as: UploadFile
  alias Database.Importer.AugmenterRule
  alias Database.Importer.Batch
  alias Database.Importer.EmailRule
  alias Database.Importer.FtpRule
  alias Database.Importer.File
  alias Database.Importer.Job
  alias Database.Repo
  import Ecto.Query, only: [from: 2]

  @doc """
  Gets a single batch.

  Returns `nil` if the Channel does not exist.

  ## Examples

      iex> get_batch!(123)
      %Channel{}

      iex> get_batch!(456)
      nil

  """
  def get_batch!(id), do: Repo.get(Batch, id)

  def get_batch_by_name!(channel_id, name) do
    Database.Repo.get_by(Batch, channel_id: channel_id, name: name)
  end

  def get_file_by_channel_id_name!(channel_id, name) do
    Database.Repo.get_by(File, channel_id: channel_id, file_name: name)
  end

  def get_file_by_channel_id_name(channel_id, name) do
    from(f in File,
      where: f.channel_id == ^channel_id,
      where: f.file_name == ^name
    )
    |> Database.Repo.one()
  end

  def get_job_by_type_and_name!(type, name) do
    Database.Repo.get_by(Job, type: type, name: name)
  end

  @doc """
  Get all augmenter rules
  """
  def get_all_augmenter_rules do
    AugmenterRule
    |> Repo.all()
    |> Repo.preload(:channel)
  end

  @doc """
  Get all email rules
  """
  def get_all_email_rules do
    EmailRule
    |> Repo.all()
    |> Repo.preload(:channels)
  end

  @doc """
  Get all ftp rules
  """
  def get_all_ftp_rules do
    FtpRule
    |> Repo.all()
    |> Repo.preload(:channels)
  end

  def all_files_for_channel(channel_id) do
    from(f in File, where: f.channel_id == ^channel_id)
    |> Database.Repo.all()
  end

  def get_new_files_by_channel_id(channel_id) do
    from(f in File, where: f.channel_id == ^channel_id, where: f.status == "new")
    |> Database.Repo.all()
  end

  @doc """
  Creates a Batch.

  ## Examples

      iex> create_batch(%{field: value})
      {:ok, %Batch{}}

      iex> create_batch(%{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def create_batch(attrs \\ %{}) do
    %Batch{}
    |> Batch.changeset(attrs)
    |> Repo.insert()
  end

  def create_file(attrs \\ %{}) do
    %File{}
    |> File.changeset(attrs)
    |> Repo.insert()
  end

  def upload_file(record_changeset, file, channel, source) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_record, record_changeset)
    |> Ecto.Multi.run(:attachment, fn _repo, %{insert_record: record} ->
      UploadFile.store(%{filename: record.file_name, path: file}, %{
        channel: channel,
        source: source
      })
    end)
    |> Ecto.Multi.run(:update_record, fn _repo,
                                         %{insert_record: record, attachment: attachment} ->
      Ecto.Changeset.change(record, attachment: Trunk.State.save(attachment))
      |> Repo.update_and_notify()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_record: record}} -> {:ok, record}
      error -> error
    end
  end

  def create_augmenter_rule(attrs \\ %{}) do
    %AugmenterRule{}
    |> AugmenterRule.changeset(attrs)
    |> Repo.insert()
  end

  def create_email_rule(attrs \\ %{}) do
    %EmailRule{}
    |> EmailRule.changeset(attrs)
    |> Repo.insert()
  end

  def create_ftp_rule(attrs \\ %{}) do
    %FtpRule{}
    |> FtpRule.changeset(attrs)
    |> Repo.insert()
  end

  def create_job(attrs \\ %{}) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Batch.

  ## Examples

      iex> update_batch(batch, %{field: new_value})
      {:ok, %Batch{}}

      iex> update_batch(batch, %{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def update_augmenter_rule(%AugmenterRule{} = rule, attrs) do
    rule
    |> AugmenterRule.changeset(attrs)
    |> Repo.update()
  end

  def update_email_rule(%EmailRule{} = rule, attrs) do
    rule
    |> EmailRule.changeset(attrs)
    |> Repo.update()
  end

  def update_ftp_rule(%FtpRule{} = rule, attrs) do
    rule
    |> FtpRule.changeset(attrs)
    |> Repo.update()
  end

  def update_batch(%Batch{} = batch, attrs) do
    batch
    |> Batch.changeset(attrs)
    |> Repo.update()
  end

  def update_file(%File{} = file, attrs) do
    file
    |> File.changeset(attrs)
    |> Repo.update()
  end

  def update_job(%Job{} = job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  @doc """

  """
  def remove_files_by_channel_id(channel_ids) when is_list(channel_ids) do
    from(f in File,
      where: f.channel_id in ^channel_ids
    )
    |> Repo.delete_all()

    # Durango.query(
    #   for: f in :files,
    #   filter: f.channel_id in ^channel_ids,
    #   remove: f in :files
    # )
    # |> Repo.execute()
  end

  def remove_files_by_channel_id(channel_id) do
    from(f in File,
      where: f.channel_id == ^channel_id
    )
    |> Repo.delete_all()

    # Durango.query(
    #   for: f in :files,
    #   filter: f.channel_id == ^channel_id,
    #   remove: f in :files
    # )
    # |> Repo.execute()
  end

  @doc """

  """
  def remove_batches_by_channel_id(channel_ids) when is_list(channel_ids) do
    from(b in Batch,
      where: b.channel_id in ^channel_ids
    )
    |> Repo.delete_all()

    # Durango.query(
    #   for: b in :batches,
    #   filter: b.channel_id in ^channel_ids,
    #   remove: b in :batches
    # )
    # |> Repo.execute()
  end

  def remove_batches_by_channel_id(channel_id) do
    from(b in Batch,
      where: b.channel_id == ^channel_id
    )
    |> Repo.delete_all()

    # Durango.query(
    #   for: b in :batches,
    #   filter: b.channel_id == ^channel_id,
    #   remove: b in :batches
    # )
    # |> Repo.execute()
  end
end
