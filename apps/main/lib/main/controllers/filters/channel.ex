defmodule Main.Filters.Channel do
  import Ecto.Query
  use Filterable.DSL
  use Filterable.Ecto.Helpers

  @options param: [search: :q]
  filter search(query, value, _conn) do
    query |> where([c], ilike(c.library, ^"%#{value}%"))
  end

  @options param: [:sort, :order], default: [sort: :xmltv_id, order: :asc], cast: :atom_unchecked
  filter order(query, %{sort: field, order: order}, _conn) do
    query |> order_by([{^order, ^field}])
  end
end
