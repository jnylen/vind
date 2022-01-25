defmodule Main.Forms.Template do
  use Formex.Template, :helper

  @moduledoc false

  defmacro __using__([]) do
    quote do
      use Formex.Template, :helper
      import Main.Forms.Template

      @spec generate_input(form :: Form.t(), field :: Field.t()) :: Phoenix.HTML.safe()
      def generate_input(form, field = %Field{}) do
        type = field.type
        data = field.data
        phoenix_opts = field.phoenix_opts

        args = [form.phoenix_form, field.name]

        main_class =
          case field.type do
            :textarea -> "form-textarea"
            :select -> "form-select"
            :checkbox -> "form-checkbox"
            _ -> "form-input"
          end

        args =
          args ++
            if Enum.member?([:select, :multiple_select], type) do
              [data[:choices]]
            else
              []
            end

        args =
          args ++
            if Enum.member?([:checkbox, :file_input], type) do
              [add_class(phoenix_opts, main_class)]
            else
              [add_class(phoenix_opts, "#{main_class} mt-1 block w-full")]
            end

        render_phoenix_input(field, args)
      end

      @spec generate_input(_form :: Form.t(), button :: Button.t()) :: Phoenix.HTML.safe()
      def generate_input(_form, button = %Button{}) do
        class = "form-button"

        phoenix_opts = add_class(button.phoenix_opts, class)

        render_phoenix_input(button, [button.label, phoenix_opts])
      end

      @spec generate_label(form :: Form.t(), field :: Field.t(), class :: String.t()) ::
              Phoenix.HTML.safe()
      def generate_label(form, field, class \\ "text-gray-700 text-sm") do
        content_tag(:span, field.label, class: "form-label " <> class)
        # Phoenix.HTML.Form.label(
        #   form.phoenix_form,
        #   field.name,
        #   field.label,
        #   class: "control-label " <> class
        # )
      end
    end
  end

  def attach_addon(field_html, field) do
    if field.opts[:addon] do
      addon = content_tag(:div, field.opts[:addon], class: "input-group-addon")
      content_tag(:div, [field_html, addon], class: "input-group")
    else
      field_html
    end
  end

  def attach_error(tags, form, field) do
    if has_error(form, field) do
      error_html =
        form
        |> get_errors(field)
        |> Enum.map(fn error ->
          content_tag(:p, format_error(error))
        end)

      error_field = content_tag(:span, error_html, class: "help-block")
      tags ++ [error_field]
    else
      tags
    end
  end

  def attach_hint(tags, form, field) do
    if has_hint(form, field) do
      hint_field = content_tag(:p, Keyword.get(field.opts, :hint, false), class: "form-hint")
      tags ++ [hint_field]
    else
      tags
    end
  end

  def attach_error_class(wrapper_class, form, field) do
    if has_error(form, field) do
      wrapper_class ++ ["has-error"]
    else
      wrapper_class
    end
  end

  def attach_required_class(wrapper_class, field) do
    if field.required do
      wrapper_class ++ ["required"]
    else
      wrapper_class
    end
  end

  defp has_hint(_form, field) do
    if Keyword.get(field.opts, :hint, false), do: true, else: false
  end

  defp has_hint(_, _), do: false
end
