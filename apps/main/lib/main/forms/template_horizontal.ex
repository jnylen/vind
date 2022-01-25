defmodule Main.Forms.TemplateHorizontal do
  use Formex.Template, :main
  use Main.Forms.Template

  @moduledoc """
  The Bootstrap 3 [horizontal](http://getbootstrap.com/css/#forms-horizontal) template
  ## Options
    * `left_column` - left column class, defaults to `col-sm-2`
    * `right_column` - left column class, defaults to `col-sm-10`
  """

  def generate_row(form, item, options \\ [])

  def generate_row(form, field = %Field{}, _options) do
    input = generate_input(form, field)
    label = generate_label(form, field)

    input = attach_addon(input, field)

    unless [:checkbox] |> Enum.member?(field.type) do
      wrap_class =
        unless Keyword.get(field.opts, :hint, false) do
          "form-label"
        else
          "form-hint-block"
        end

      tags =
        content_tag(:div, attach_hint([attach_error([label], form, field)], form, field),
          class: wrap_class
        )

      wrapper_class =
        ["form-block"]
        |> attach_error_class(form, field)
        |> attach_required_class(field)

      content_tag(:label, [tags, input], class: Enum.join(wrapper_class, " "))
    else
      cb_label = attach_hint([attach_error([label], form, field)], form, field)

      cb_wrap_class =
        unless Keyword.get(field.opts, :hint, false) do
          "form-label ml-2"
        else
          "form-hint-block ml-2"
        end

      tags = content_tag(:div, cb_label, class: cb_wrap_class)

      wrapper_class =
        ["form-flex"]
        |> attach_error_class(form, field)
        |> attach_required_class(field)

      content_tag(:label, [input, tags], class: Enum.join(wrapper_class, " "))
    end
  end

  def generate_row(form, button = %Button{}, _options) do
    input = generate_input(form, button)
    content_tag(:div, input, class: Enum.join(["block"], " "))
  end
end
