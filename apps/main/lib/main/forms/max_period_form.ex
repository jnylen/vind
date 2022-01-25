defmodule Main.Forms.MaxPeriodForm do
  use Formex.Type
  use Formex.Ecto.Type

  def build_form(form) do
    form
    |> add(:type, :select,
      choices: [{"Days", "days"}, {"Weeks", "weeks"}, {"Months", "months"}],
      label: "Period Type",
      required: false,
      phoenix_opts: [prompt: "Period Type"]
    )
    |> add(:amount, :number_input,
      label: "Amount",
      required: false,
      phoenix_opts: [placeholder: "Amount"]
    )
  end
end
