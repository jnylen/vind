defmodule Shared do
  @moduledoc """
  Documentation for Shared.
  """

  def version(), do: System.get_env("RELEASE_VSN") || "dev"
end
