defmodule Main.Filters.Batch do
  import Ecto.Query
  use Filterable.DSL
  use Filterable.Ecto.Helpers

  @options param: [search: :channel_id]
  filter channel_id(query, value, _conn) do
    query |> where(channel_id: ^value) |> order_by([{:desc, :name}])
  end

  @options param: [search: :status]
  filter status(query, value, _conn) do
    query |> where(status: ^value)
  end

  # @options param: [search: [:field, :order]],
  #          default: [search: [field: :inserted_at, order: :asc]],
  #          cast: :atom_unchecked
  # filter sort(query, %{field: field, order: order}, _conn) do
  #   query
  #   |> order_by([{^order, ^field}])
  # end

  @options param: [search: :q]
  filter search(query, value, _conn) do
    query |> where([b], ilike(b.name, ^"%#{value}%"))
  end

  @options param: [:sort, :order], default: [sort: :name, order: :desc], cast: :atom_unchecked
  filter order(query, %{sort: field, order: order}, _conn) do
    query |> order_by([{^order, ^field}])
  end
end
