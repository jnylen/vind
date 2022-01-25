defmodule Main.Forms.EmailRuleForm do
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
    |> add(:address, :text_input,
      label: "Address",
      phoenix_opts: [placeholder: "Address"],
      required: true,
      validation: [presence: true]
    )
    |> add(:subject, :text_input,
      label: "Subject",
      phoenix_opts: [placeholder: "Subject"],
      required: false
    )
    |> add(:file_name, :text_input,
      label: "File name",
      phoenix_opts: [placeholder: "Should start with ^"],
      required: false
    )
    |> add(:file_extension, :text_input,
      label: "File extension",
      phoenix_opts: [placeholder: "Should start with ^"],
      required: false
    )
    |> add(:save, :submit, label: "Save", phoenix_opts: [class: "dark"])
  end
end
