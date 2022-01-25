defmodule Augmenter.Fixups do
  @moduledoc """
  Basic fixups of faulty data. Such as wrong title etc.
  """
  use Augmenter.Base

  @doc """
  Set the category based on remoteref
  """
  @impl true
  def filter(_airing, %{matchby: "set_category", remoteref: remoteref}) do
    %{category: remoteref |> String.split(",")}
  end

  @doc """
  Set program_type based on remoteref
  """
  @impl true
  def filter(_airing, %{matchby: "setprogram_type", remoteref: remoteref}) do
    %{program_type: remoteref}
  end

  @impl true
  def filter(_airing, _rules), do: {:ok, %{}}
end
