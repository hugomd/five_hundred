defmodule FiveHundred.BidTest do
  use ExUnit.Case

  alias FiveHundred.{Bid}

  describe "bid generation" do
    test "generates correct number of bids" do
      result = Bid.bids()
      assert length(result) == 28
    end
  end

  describe "bid comparison" do
    test "a < b" do
      a = %Bid{points: 0}
      b = %Bid{points: 1}
      assert Bid.compare(a, b) == :lt
    end

    test "a > b" do
      a = %Bid{points: 1}
      b = %Bid{points: 0}
      assert Bid.compare(a, b) == :gt
    end

    test "a == b" do
      a = %Bid{points: 1}
      b = %Bid{points: 1}
      assert Bid.compare(a, b) == :eq
    end
  end
end
