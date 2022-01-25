defmodule Database.Regions do
  @languages Application.app_dir(:iso639_elixir, "priv/iso-639/data/iso_639-2.json")
             |> File.read!()
             |> Jsonrs.decode!()
             |> Enum.uniq_by(fn {_, v} -> v end)
             |> Enum.reject(fn {_, lang} ->
               Map.get(lang, "639-1") |> is_nil()
             end)
             |> Enum.map(fn {_, lang} ->
               {Map.get(lang, "en", []) |> List.first(), Map.get(lang, "639-1")}
             end)
             |> Enum.sort()

  def languages_for_form, do: @languages
  def languages, do: @languages |> Enum.map(fn {_name, language} -> language end)
end
