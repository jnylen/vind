defmodule Importer.Base do
  @moduledoc """
  The Importer Behaviour and base.

  Should be used when building importers.
  """

  @callback clean_up_map(map :: Map.t()) :: Map.t()
  @callback force_update(grabber_name :: String.t(), config :: Map.t() | nil) :: any
  @callback import_channels(
              grabber_name :: String.t(),
              config :: Map.t() | nil,
              module :: Atom.t()
            ) :: any
  @callback import_channel(channel :: Map.t(), config :: Map.t(), module :: Atom.t(), type :: any) ::
              {:ok, result} | {:error, result}
            when result: any
  @callback short_update(channel :: Map.t(), config :: Map.t(), module :: Atom.t(), type :: any) ::
              {:ok, result} | {:error, result}
            when result: any

  defmacro __using__(_opts) do
    # Add functions to importers
    quote do
      @behaviour Importer.Base
      alias Importer.Base

      @impl true
      defdelegate clean_up_map(map), to: Base
      defoverridable clean_up_map: 1

      # @impl true
      # def force_update(_grabber_name, nil), do: {:error, "no grabber with that name"}
      # defoverridable force_update: 2

      @impl true
      defdelegate import_channels(grabber_name, config, module \\ __MODULE__), to: Base
      defoverridable import_channels: 2

      # @impl true
      # def import_channel(channels, config, module \\ __MODULE__, type \\ nil)
      # defdelegate import_channel(channels, config, module, type), to: Base

      # @impl true
      # def short_update(_channel, _config, _module, _type), do: {:error, "not implemented"}
      # defoverridable short_update: 4
    end
  end

  def import_channel([], _config, _module), do: []

  def import_channel([channel | channels], config, module) do
    Worker.Importer.enqueue(%{"channel" => channel.xmltv_id})

    # Gets sent to the queue
    apply(module, :import_channel, [channels, config])
  end

  def clean_up_map(map),
    do:
      map
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{})

  @doc """

  """
  def import_channels(_grabber_name, nil, _module), do: {:error, "no grabber with that name"}

  def import_channels(grabber_name, config, module) do
    # Run Importer
    grabber_name
    |> Database.Network.get_channels_by_grabber!()
    |> (&apply(module, :import_channel, [&1, config])).()
  end
end
