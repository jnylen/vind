defmodule AugmenterTest do
  use ExUnit.Case
  doctest Augmenter

  test "greets the world" do
    assert Augmenter.hello() == :world
  end
end
