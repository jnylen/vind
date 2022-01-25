defmodule Database.Network.Airing do
  @moduledoc """
  Programme airings on a specific channel.
  """
  use Database.Schema
  import Ecto.Changeset

  alias Database.Helpers.Language

  @qualifier_types [
    "3d",
    "dubbed",
    "catchup",
    "CC",
    "HD",
    "UHD",
    "smallscreen",
    "widescreen",
    "stereo",
    "surround",
    "DD 5.1",
    "live",
    "rerun",
    "new",
    "premiere",
    "color",
    "black_white"
  ]

  @translation_types [
    "original",
    "content",
    "series",
    "long",
    "medium",
    "short",
    "season",
    "episode"
  ]

  @image_types [
    "episode",
    "series",
    "content"
  ]

  @credit_types [
    "actor",
    "director",
    "producer",
    "presenter",
    "guest",
    "commentator",
    "writer"
  ]

  @program_types [
    "movie",
    "series",
    "sports",
    "sports_event"
  ]

  @metadata_types [
    "metagraph",
    "imdb"
  ]

  schema "airings" do
    belongs_to(:channel, Database.Network.Channel)
    belongs_to(:batch, Database.Importer.Batch)

    many_to_many(:image_files, Database.Image.File,
      join_through: "airings_image_files",
      join_keys: [airing_id: :id, image_id: :id],
      on_replace: :delete,
      on_delete: :delete_all
    )

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    # Translations
    embeds_many :descriptions, Description, on_replace: :delete do
      field(:value, :string)
      field(:language, :string)
      field(:type, :string)
    end

    embeds_many :titles, Title, on_replace: :delete do
      field(:value, :string)
      field(:language, :string)
      field(:type, :string)
    end

    embeds_many :subtitles, Subtitle, on_replace: :delete do
      field(:value, :string)
      field(:language, :string)
      field(:type, :string)
    end

    embeds_many :blines, Bline, on_replace: :delete do
      field(:value, :string)
      field(:language, :string)
      field(:type, :string)
    end

    field(:category, {:array, :string}, default: [])
    field(:program_type, :string)
    field(:season, :integer)
    field(:episode, :integer)
    field(:of_episode, :integer)
    field(:production_date, :date)
    field(:production_countries, {:array, :string}, default: [])
    field(:qualifiers, {:array, :string}, default: [])
    field(:url, :string)

    # Previously Shown (First or Latest)
    embeds_one :previously_shown, PreviouslyShown, on_replace: :update do
      # XMLTV ID
      field(:channel, :string)
      field(:datetime, :utc_datetime)
    end

    # Sport item
    embeds_one :sport, Sport, on_replace: :update do
      field(:game, :integer)
      field(:play_date, :naive_datetime)

      embeds_one :event, Event, on_replace: :update do
        field(:name, :string)
        field(:type, :string)
      end

      embeds_many :teams, Team, on_replace: :delete do
        field(:name, :string)
        field(:type, :string)
      end
    end

    # Image
    field(:images, {:array, :map}, virtual: true)

    # Credit
    embeds_many :credits, Credit, on_replace: :delete do
      field(:person, :string)
      field(:role, :string)
      field(:type, :string)
    end

    # Metadata i.e. external ids
    embeds_many :metadata, Metadata, on_replace: :delete do
      field(:type, :string)
      field(:value, :string)
    end

    timestamps()
  end

  def changeset(airing, params \\ %{}) do
    airing
    |> cast(params, [
      :channel_id,
      :start_time,
      :end_time,
      :category,
      :program_type,
      :batch_id,
      :season,
      :episode,
      :of_episode,
      :production_date,
      :production_countries,
      :qualifiers,
      :url
    ])
    |> validate_required([:start_time, :batch_id, :channel_id, :titles])
    |> unique_constraint(:start_time, name: :airings_channel_id_start_time_index)
    |> cast_embed(:titles, required: true, with: &translation_changeset/2)
    |> cast_embed(:descriptions, with: &translation_changeset/2)
    |> cast_embed(:subtitles, with: &translation_changeset/2)
    |> cast_embed(:blines, with: &translation_changeset/2)
    |> cast_embed(:credits, with: &credit_changeset/2)
    |> cast_embed(:metadata, with: &metadata_changeset/2)
    |> cast_embed(:sport, with: &sport_changeset/2)
    |> validate_subset(:qualifiers, @qualifier_types)
    |> validate_inclusion(:program_type, @program_types)
    |> validate_times(:end_time)
    |> validate_subset(
      :production_countries,
      Enum.map(CountryData.all_countries(), fn c -> c["alpha2"] end)
    )
    |> put_images(Map.get(params, :migrated_image_files, []))
  end

  defp put_images(changeset, []), do: changeset
  defp put_images(changeset, nil), do: changeset

  defp put_images(changeset, images) do
    changeset
    |> put_assoc(:image_files, images)
  end

  defp validate_times(changeset, field) do
    validate_change(changeset, field, fn _, end_time ->
      cond do
        is_nil(end_time) ->
          []

        DateTime.compare(end_time, fetch_field(changeset, :start_time) |> to_value()) == :gt ->
          []

        true ->
          [{field, "end_time is earlier than start_time"}]
      end
    end)
  end

  defp to_value({_, value}), do: value

  defp translation_changeset(translation, params) do
    translation
    |> cast(
      params,
      [
        :value,
        :language,
        :type
      ]
    )
    |> validate_required([:value, :type])
    |> validate_inclusion(:type, @translation_types)
    |> validate_inclusion(:language, Language.all())
  end

  defp credit_changeset(credit, params) do
    credit
    |> cast(
      params,
      [
        :person,
        :role,
        :type
      ]
    )
    |> validate_required([:person, :type])
    |> validate_inclusion(:type, @credit_types)
  end

  defp image_changeset(image, params) do
    image
    |> cast(
      params,
      [
        :url,
        :source,
        :author,
        :type,
        :language
      ]
    )
    |> validate_required([:url, :source, :type])
    |> validate_inclusion(:type, @image_types)
    |> validate_inclusion(:language, Language.all())
  end

  defp metadata_changeset(metadata, params) do
    metadata
    |> cast(
      params,
      [
        :type,
        :value
      ]
    )
    |> validate_required([:type, :value])
  end

  defp sport_event_changeset(sport, params) do
    sport
    |> cast(
      params,
      [
        :type,
        :name
      ]
    )
    |> validate_required([:type, :name])
  end

  defp sport_team_changeset(sport, params) do
    sport
    |> cast(
      params,
      [
        :type,
        :name
      ]
    )
    |> validate_required([:type, :name])
  end

  defp sport_changeset(sport, params) do
    sport
    |> cast(
      params,
      [
        :game,
        :play_date
      ]
    )
    |> cast_embed(:event, with: &sport_event_changeset/2)
    |> cast_embed(:teams, with: &sport_team_changeset/2)
  end
end
