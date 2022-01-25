defmodule Database.Network.Channel do
  @moduledoc """
  A tv channel or radiostation.
  """
  use Database.Schema
  import Ecto.Changeset

  @logo_types [
    "blackwhite",
    "color"
  ]

  schema "channels" do
    belongs_to(:source_channel, Database.Network.Channel)
    many_to_many(:ftp_rules, Database.Importer.FtpRule, join_through: "ftp_rules_channels")
    many_to_many(:email_rules, Database.Importer.EmailRule, join_through: "email_rules_channels")

    embeds_many :display_names, DisplayName, on_replace: :delete do
      field(:value, :string)
      field(:language, :string)
      formex_collection_child()
    end

    field(:xmltv_id, :string)
    field(:new_xmltv_id, :string)
    field(:channel_groups, {:array, :string}, default: [])
    field(:library, :string)
    field(:export, :boolean)
    field(:grabber_info, :string)
    field(:default_prog_type, :string)
    field(:default_category, :string)
    field(:schedule_languages, {:array, :string})
    field(:url, :string)
    field(:schedule, :string)
    field(:augment, :boolean)

    embeds_many :config_list, Config, on_replace: :delete do
      field(:key, :string)
      field(:value, :string)

      formex_collection_child()
    end

    embeds_many :flags, Flag, on_replace: :delete do
      field(:function, :string)
      field(:type, :string)
      field(:value, :string)

      formex_collection_child()
    end

    embeds_many :sources, Source, on_replace: :delete do
      field(:xmltv_id, :string)
      field(:day, :string)
      field(:time, :string)

      formex_collection_child()
    end

    embeds_one :max_period, MaxPeriod, on_replace: :delete do
      field(:amount, :integer)
      field(:type, :string)
    end

    # Logos
    embeds_many :logos, Logo, on_replace: :delete do
      field(:url, :string)
      field(:extension, :string)
      field(:height, :integer)
      field(:width, :integer)
      field(:type, :string)

      timestamps()
    end

    timestamps()
  end

  def changeset(channel, params \\ %{}) do
    channel
    |> cast(params |> from_struct(), [
      :source_channel_id,
      :xmltv_id,
      :new_xmltv_id,
      :channel_groups,
      :export,
      :grabber_info,
      :default_prog_type,
      :default_category,
      :schedule_languages,
      :url,
      :augment,
      :schedule,
      :library
    ])
    |> cast_embed(:display_names, required: true, with: &changeset_display_names/2)
    |> cast_embed(:logos, with: &changeset_logos/2)
    |> cast_embed(:config_list, with: &changeset_config_list/2)
    |> cast_embed(:flags, with: &changeset_flags/2)
    |> cast_embed(:sources, with: &changeset_sources/2)
    |> cast_embed(:max_period, with: &changeset_max_period/2)
    |> validate_required([:xmltv_id, :schedule, :schedule_languages])
  end

  def changeset_display_names(name, params \\ %{}) do
    name
    |> cast(params |> from_struct(), [
      :value,
      :language
    ])
    |> validate_required([:value, :language])
  end

  def changeset_config_list(config, params \\ %{}) do
    config
    |> cast(params |> from_struct(), [
      :value,
      :key
    ])
    |> validate_required([:value, :key])
  end

  def changeset_flags(flag, params \\ %{}) do
    flag
    |> cast(params |> from_struct(), [
      :function,
      :type,
      :value
    ])
    |> validate_required([:function, :type, :value])
  end

  def changeset_sources(source, params \\ %{}) do
    source
    |> cast(params |> from_struct(), [
      :day,
      :time,
      :xmltv_id
    ])
    |> validate_required([:day, :time, :xmltv_id])
  end

  def changeset_max_period(source, params \\ %{}) do
    source
    |> cast(params |> from_struct(), [
      :type,
      :amount
    ])
  end

  def changeset_logos(logo, params \\ %{}) do
    logo
    |> cast(params |> from_struct(), [
      :url,
      :extension,
      :type,
      :height,
      :width
    ])
    |> validate_required([:url, :type, :extension, :height, :width])
    |> validate_inclusion(:type, @logo_types)
  end

  def config_transform_to(map, "list") do
    map
    |> Enum.into([])
    |> Enum.map(fn {key, val} ->
      %{
        key: to_string(key),
        value: val
      }
    end)
  end

  def config_transform_to(list, "map") do
    list
    |> Enum.map(fn map ->
      {
        Map.get(map, :key) |> String.to_atom(),
        Map.get(map, :value)
      }
    end)
    |> Enum.into(%{})
  end

  defp from_struct(struct) do
    struct
    |> Map.from_struct()
  rescue
    _ -> struct
  end
end
