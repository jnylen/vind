defmodule Main.Filters.File do
  import Ecto.Query
  use Filterable.DSL
  use Filterable.Ecto.Helpers

  @options param: [search: :channel_id]
  filter channel_id(query, value, _conn) do
    query |> where(channel_id: ^value) |> order_by([{:asc, :file_name}])
  end

  @options param: [search: :status]
  filter status(query, value, _conn) do
    query |> where(status: ^value)
  end

  # @options param: [:field, :order],
  #          default: [field: :inserted_at, order: :asc],
  #          cast: :atom_unchecked
  # filter sort(query, %{field: field, order: order}, _conn) do
  #   query
  #   |> order_by([{^order, ^field}])
  # end

  @options param: [search: :q]
  filter search(query, value, _conn) do
    query |> where([f], ilike(f.file_name, ^"%#{value}%"))
  end


  @options param: [:sort, :order], default: [sort: :file_name, order: :asc], cast: :atom_unchecked
  filter order(query, %{sort: field, order: order}, _conn) do
    query |> order_by([{^order, ^field}])
  end
end
