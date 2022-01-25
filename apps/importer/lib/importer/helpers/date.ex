defmodule Importer.Helpers.Date do
  def first_day_of_week(year, week, weekstart \\ :mon) do
    {{year, 1, 4}, {06, 00, 00}}
    |> Timex.to_datetime("Etc/UTC")
    |> Timex.shift(weeks: week - 1)
    |> Timex.beginning_of_week(weekstart)
    |> DateTime.to_date()
  end

  def last_day_of_week(year, week, weekstart \\ 1) do
    {{year, 1, 4}, {06, 00, 00}}
    |> Timex.to_datetime("Etc/UTC")
    |> Timex.shift(weeks: week - 1)
    |> Timex.end_of_week(weekstart)
    |> DateTime.to_date()
  end
end
