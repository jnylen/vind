defmodule Main.Forms.FlagForm do
  use Formex.Type
  use Formex.Ecto.Type

  def build_form(form) do
    form
    |> add(:function, :select,
      choices: [{"Add", "add"}, {"Delete", "delete"}],
      label: "Function",
      required: true,
      phoenix_opts: [prompt: "How should this be handled"],
      validation: [presence: true]
    )
    |> add(:type, :text_input,
      label: "Field",
      required: true,
      phoenix_opts: [placeholder: "Field"],
      validation: [presence: true]
    )
    |> add(:value, :text_input,
      label: "Value",
      required: true,
      phoenix_opts: [placeholder: "Value"],
      validation: [presence: true]
    )
  end
end
