defmodule Main.Forms.ConfigForm do
  use Formex.Type
  use Formex.Ecto.Type

  def build_form(form) do
    form
    |> add(:key, :text_input,
      label: "Key",
      required: true,
      phoenix_opts: [placeholder: "Config Key"],
      validation: [presence: true]
    )
    |> add(:value, :text_input,
      label: "Value",
      required: true,
      phoenix_opts: [placeholder: "Config Value"],
      validation: [presence: true]
    )
  end
end
