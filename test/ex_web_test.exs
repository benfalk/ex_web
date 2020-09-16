defmodule ExWebTest do
  use ExUnit.Case
  doctest ExWeb

  test "greets the world" do
    assert ExWeb.hello() == :world
  end
end
