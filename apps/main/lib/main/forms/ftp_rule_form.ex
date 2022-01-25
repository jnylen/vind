defmodule Main.Forms.FtpRuleForm do
  use Formex.Type
  use Formex.Ecto.Type
  alias Formex.Ecto.CustomField.SelectAssoc

  def build_form(form) do
    form
    |> add(:channels, SelectAssoc,
      label: "Channels",
      required: true,
      choice_label: :xmltv_id,
      validation: [presence: true],
      phoenix_opts: [class: "choicesjs"]
    )
    |> add(:directory, :text_input,
      label: "Directory",
      phoenix_opts: [placeholder: "Should start with ^"],
      required: true,
      validation: [presence: true]
    )
    |> add(:file_name, :text_input,
      label: "File name",
      phoenix_opts: [placeholder: "Should start with ^"]
    )
    |> add(:file_extension, :text_input,
      label: "File extension",
      phoenix_opts: [placeholder: "Should start with ^"],
      required: false
    )
    |> add(:save, :submit, label: "Save", phoenix_opts: [class: "dark"])
  end
end
