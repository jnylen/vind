defmodule Main.Forms.ChannelForm do
  use Formex.Type
  use Formex.Ecto.Type
  alias Formex.Ecto.CustomField.SelectAssoc

  def build_form(form) do
    form
    |> add(:source_channel_id, :select,
      label: "Source Channel",
      required: false,
      choice_label: :xmltv_id,
      choices: Database.Repo.all(Database.Network.Channel) |> Enum.map(fn channel -> {channel.xmltv_id, channel.id} end),
      phoenix_opts: [prompt: "Select a channel", class: "choicesjs"]
    )
    |> add(:display_names, Main.Forms.DisplayNameForm)
    |> add(:config_list, Main.Forms.ConfigForm)
    |> add(:sources, Main.Forms.SourceForm)
    |> add(:flags, Main.Forms.FlagForm)
    |> add(:max_period, Main.Forms.MaxPeriodForm)
    |> add(:xmltv_id, :text_input,
      label: "XMLTV ID",
      required: true,
      validation: [presence: true]
    )
    |> add(:schedule, :text_input,
      label: "Schedule (Cron-format)",
      required: true,
      validation: [presence: true]
    )
    |> add(:new_xmltv_id, :text_input, label: "New XMLTV ID", required: false)
    |> add(:library, :text_input, label: "Library", required: true, validation: [presence: true])
    |> add(:augment, :checkbox, label: "Augment?", required: false, hint: "Should this be augmented?")
    |> add(:export, :checkbox, label: "Export?", required: false, hint: "Should this be exported?")
    |> add(:grabber_info, :text_input, label: "Grabber Info", required: false)
    |> add(:default_prog_type, :text_input, label: "Default Program Type", required: false)
    |> add(:default_category, :text_input, label: "Default Category", required: false)
    |> add(:schedule_languages, :multiple_select,
      label: "Language of the schedule",
      choices: Database.Regions.languages_for_form(),
      required: true,
      phoenix_opts: [class: "choicesjs"],
      validation: [presence: true]
    )
    |> add(:url, :text_input, label: "URL", required: false)
    |> add(:save, :submit, label: "Save", phoenix_opts: [class: "dark"])
  end
end
