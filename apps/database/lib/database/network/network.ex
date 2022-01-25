defmodule Database.Network do
  @moduledoc """
  The User context.
  """

  # require Durango
  alias Database.Repo

  alias Database.Network.Airing
  alias Database.Network.Channel
  # alias Database.Network.Group
  # alias Database.Helpers
  import Ecto.Query, only: [from: 2]

  @doc """
  Gets a single chanel.

  Returns `nil` if the Channel does not exist.

  ## Examples

      iex> get_channel!(123)
      %Channel{}

      iex> get_channel!(456)
      nil

  """
  def get_channel!(value) do
    Repo.get(Channel, value)
  rescue
    Ecto.Query.CastError -> get_channel_by_xmltv_id!(value)
  end

  def get_channel_by_xmltv_id!(xmltv_id) do
    Database.Repo.get_by(Channel, xmltv_id: xmltv_id)
  end

  def get_channels_by_group!(group) do
    groups = [group]

    from(c in Channel,
      where: fragment("? @> ?::varchar[]", c.channel_groups, ^groups)
    )
    |> Repo.all()
  end

  def get_channels_by_grabber!(grabber) do
    from(c in Channel,
      where: c.grabber == ^grabber
    )
    |> Repo.all()
  end

  def get_channels(nil), do: []

  def get_channels(ids) do
    Repo.all(from(c in Channel, where: c.id in ^ids))
  end

  def get_all_channels do
    Repo.all(Channel)
  end

  @doc """
  Gets a single airing.

  Returns `nil` if the Airing does not exist.

  ## Examples

  iex> get_airing!(123)
  %Airing{}

  iex> get_airing!(456)
  nil

  """
  def get_airing!(id), do: Repo.get(Airing, id)

  def get_airings_by_batch_id!(batch) when is_map(batch),
    do: get_airings_by_batch_id!(batch.id)

  def get_airings_by_batch_id!(batch_id) do
    from(a in Airing,
      where: a.batch_id == ^batch_id,
      order_by: a.start_time
    )
    |> Repo.all()
  end

  def get_airings_by_channel_id_and_dates!(channel_id, start_date, end_date) do
    from(a in Airing,
      where: a.channel_id == ^channel_id,
      where: a.start_time >= ^start_date,
      where: a.start_time < ^end_date,
      order_by: a.start_time
    )
    |> Repo.all()
    |> Repo.preload(:image_files)
  end

  def next_airing_by_start(channel_id, start_time) do
    from(a in Airing,
      where: a.channel_id == ^channel_id,
      where: a.start_time > ^start_time,
      limit: 1,
      order_by: a.start_time
    )
    |> Repo.one()
  end

  @doc """
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a airing.

  ## Examples

      iex> create_airing(%{field: value})
      {:ok, %Airing{}}

      iex> create_airing(%{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def create_airing(attrs \\ %{}) do
    %Airing{}
    |> Airing.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Remove airings based by channel_id
  """
  def remove_airings_by_channel_id(channel_ids) when is_list(channel_ids) do
    from(a in Airing,
      where: a.channel_id in ^channel_ids
    )
    |> Repo.delete_all()
  end

  def remove_airing_by_channel_id(channel) when is_map(channel),
    do: remove_airing_by_channel_id(channel.id)

  def remove_airing_by_channel_id(channel_id) do
    from(a in Airing,
      where: a.channel_id == ^channel_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Remove airings based by batch_id
  """
  def remove_airing_by_batch_id(batch) when is_map(batch),
    do: remove_airing_by_batch_id(batch.id)

  def remove_airing_by_batch_id(batch_id) do
    from(a in Airing,
      where: a.batch_id == ^batch_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a airing.

  ## Examples

      iex> update_airing(airing, %{field: new_value})
      {:ok, %Airing{}}

      iex> update_airing(airing, %{field: bad_value})
      {:error, %Durango.Changeset{}}

  """
  def update_airing(%Airing{} = airing, attrs) do
    airing
    |> Airing.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Remove all linked content before deleting a channel
  """
  def purge_channel(%Channel{} = channel) do
    channel
    |> Repo.delete()

    # Airings
    # Batches
    # Files
    # Jobs
    # Augmenter Rules
    # FTP Rules
    # Email Rules
    # Files
  end
end
