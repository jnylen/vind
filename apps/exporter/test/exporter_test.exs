defmodule ExporterTest do
  use ExUnit.Case
  doctest Exporter

  test "greets the world" do
    assert Exporter.hello() == :world
  end
end
