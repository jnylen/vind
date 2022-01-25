defmodule Main.Filters.Airing do
  import Ecto.Query
  use Filterable.DSL
  use Filterable.Ecto.Helpers

  @options param: [search: :channel_id]
  filter channel_id(query, value, _conn) do
    query |> where(channel_id: ^value) |> order_by([{:desc, :start_time}])
  end

  @options param: [search: :batch_id]
  filter batch_id(query, value, _conn) do
    query |> where(batch_id: ^value) |> order_by([{:desc, :start_time}])
  end

  # @options param: [:field, :order],
  #          default: [field: :start_time, order: :asc],
  #          cast: :atom_unchecked
  # filter sort(query, %{field: field, order: order}, _conn) do
  #   query
  #   |> order_by([{^order, ^field}])
  # end

  # @options param: :q
  # filter search(query, value, _conn) do
  #   query |> where([f], ilike(f.file_name, ^"%#{value}%"))
  # end


  @options param: [:sort, :order], default: [sort: :start_time, order: :desc], cast: :atom_unchecked
  filter order(query, %{sort: field, order: order}, _conn) do
    query |> order_by([{^order, ^field}])
  end
end
