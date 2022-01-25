defmodule Main.Forms.DisplayNameForm do
  use Formex.Type
  use Formex.Ecto.Type

  def build_form(form) do
    form
    |> add(:value, :text_input,
      label: "Value",
      required: true,
      phoenix_opts: [placeholder: "Channel One Sweden"],
      validation: [presence: true]
    )
    |> add(:language, :select,
      label: "Language",
      choices: Database.Regions.languages_for_form(),
      required: true,
      phoenix_opts: [prompt: "Select a language", class: "choicesjs"],
      validation: [presence: true]
    )
  end
end
