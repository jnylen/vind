defmodule Main.Forms.SourceForm do
  use Formex.Type
  use Formex.Ecto.Type

  def build_form(form) do
    form
    |> add(:xmltv_id, :text_input,
      label: "XMLTV ID",
      required: true,
      phoenix_opts: [placeholder: "xmltv.id.se"],
      validation: [presence: true]
    )
    |> add(:day, :text_input,
      label: "Day",
      phoenix_opts: [placeholder: "Day"],
      required: true,
      validation: [presence: true]
    )
    |> add(:time, :text_input,
      label: "Timerange",
      phoenix_opts: [placeholder: "0000-1230"]
    )
  end
end
