defmodule Importer.Helpers.Translation do
  alias Database.Translation, as: DBTranslation

  defmacro __using__(_opts) do
    # Add functions to importers
    quote do
      @doc """
      Try to split a string but if its nil just return nil.
      """
      def try_to_split(nil, _), do: nil

      def try_to_split(string, splitter) do
        string
        |> String.split(splitter)
      end

      @doc """
      Append categories either in a list (of structs) or a struct and add it to an airing struct.
      """
      def append_categories(airing, nil), do: airing

      def append_categories(airing, list) when is_list(list) and list == [], do: airing

      def append_categories(airing, list) when is_list(list) do
        Enum.map(list, &append_categories(airing, &1))
        |> Enum.reduce(fn x, acc ->
          merge_maps(acc, x)
        end)
      end

      def append_categories(
            %{} = airing,
            %Database.Translation.Category{} = category
          ) do
        returned_data =
          %{program_type: category.program_type, category: category.category}
          |> Enum.filter(fn {_, v} -> v != nil && v != [] end)
          |> Enum.into(%{})

        merge_maps(airing, returned_data)
      end

      def append_categories(airing, error) do
        import Logger
        Logger.info("Couldn't match an category to a known type #{inspect(error)}")

        airing
      end

      @doc """
      Append country either in a list (of structs) or a struct and add it to an airing struct.
      """
      def append_countries(airing, nil), do: airing

      def append_countries(airing, list) when is_list(list) and list == [], do: airing

      def append_countries(airing, list) when is_list(list) do
        Enum.map(list, &append_countries(airing, &1))
        |> Enum.reduce(fn x, acc ->
          merge_maps(acc, x)
        end)
      end

      def append_countries(
            %{} = airing,
            %Database.Translation.Country{} = country
          ) do
        returned_data =
          %{production_countries: [country.iso_code]}
          |> Enum.filter(fn {_, v} -> v != nil && v != [] && v != [nil] end)
          |> Enum.into(%{})

        merge_maps(airing, returned_data)
      end

      def append_countries(airing, error) do
        import Logger
        Logger.info("Couldn't match an country to a known type #{inspect(error)}")

        airing
      end

      # Merge two maps and append an array if it exists and unique it.
      defp merge_maps(original_map, new_map) when new_map == %{} do
        original_map
      end

      defp merge_maps(original_map, new_map) do
        Map.merge(original_map, new_map, fn _k, om, nm ->
          # Is om a nil? Replace with nm
          cond do
            om == nil -> nm
            is_list(om) && is_list(nm) -> Enum.uniq(om ++ nm)
            true -> nm
          end
        end)
      end
    end
  end

  @moduledoc """
  Translates stuff into the standard genres and program_types
  """

  @doc """
  Find or create a category
  """
  def translate_category(_type, nil), do: nil
  def translate_category(_type, ""), do: nil
  def translate_category(_type, []), do: nil
  def translate_category(_type, [[]]), do: nil

  def translate_category(type, list) when is_list(list),
    do: Enum.map(list, &translate_category(type, &1))

  def translate_category(type, string) do
    case DBTranslation.get_category_by_string!(type, string) do
      nil ->
        try do
          {:ok, cat} = DBTranslation.create_category(type |> String.downcase(), string)

          cat
        catch
          _ -> nil
        end

      cat ->
        cat
    end
  end

  @doc """
  Find or create a country
  """
  def translate_country(_type, nil), do: nil
  def translate_country(_type, ""), do: nil

  def translate_country(type, list) when is_list(list),
    do: Enum.map(list, &translate_country(type, &1))

  def translate_country(type, string) do
    case DBTranslation.get_country_by_string!(type, string) do
      nil ->
        try do
          {:ok, country} = DBTranslation.create_country(type |> String.downcase(), string)

          country
        catch
          _ -> nil
        end

      cat ->
        cat
    end
  end
end
