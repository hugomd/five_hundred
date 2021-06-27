defmodule FiveHundred.BidTest do
  use ExUnit.Case

  alias FiveHundred.{Bid}

  describe "tricks" do
    test "a < b" do
      a = %Bid{suit: :spades, tricks: 6}
      b = %Bid{suit: :spades, tricks: 7}
      assert Bid.compare(a, b) == :lt
    end

    test "a > b" do
      a = %Bid{suit: :spades, tricks: 7}
      b = %Bid{suit: :spades, tricks: 6}
      assert Bid.compare(a, b) == :gt
    end

    test "a == b" do
      a = %Bid{suit: :spades, tricks: 6}
      b = %Bid{suit: :spades, tricks: 6}
      assert Bid.compare(a, b) == :eq
    end
  end

  describe "suits" do
    test "a < b" do
      a = %Bid{suit: :spades, tricks: 6}
      b = %Bid{suit: :hearts, tricks: 6}
      assert Bid.compare(a, b) == :lt
    end

    test "a > b" do
      a = %Bid{suit: :hearts, tricks: 6}
      b = %Bid{suit: :spades, tricks: 6}
      assert Bid.compare(a, b) == :gt
    end
  end

  describe "suits and tricks" do
    test "H6 < D7" do
      a = %Bid{suit: :hearts, tricks: 6}
      b = %Bid{suit: :diamonds, tricks: 7}
      assert Bid.compare(a, b) == :lt
    end

    test "H7 > D7" do
      a = %Bid{suit: :hearts, tricks: 7}
      b = %Bid{suit: :diamonds, tricks: 7}
      assert Bid.compare(a, b) == :gt
    end
  end
end
