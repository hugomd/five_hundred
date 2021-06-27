defmodule FiveHundred.GameTest do
  use ExUnit.Case

  alias FiveHundred.{Bid, Game}

  test "determine highest bid" do
    bids = [
      %Bid{suit: :spades, tricks: 6},
      %Bid{suit: :hearts, tricks: 6},
      %Bid{suit: :spades, tricks: 8},
      %Bid{suit: :diamonds, tricks: 7}
    ]

    assert Game.highest_bid(bids) == %Bid{suit: :spades, tricks: 8}
  end

  test "determine highest bid with tricks" do
    bids = [
      %Bid{suit: :spades, tricks: 6},
      %Bid{suit: :spades, tricks: 7},
      %Bid{suit: :spades, tricks: 8}
    ]

    assert Game.highest_bid(bids) == %Bid{suit: :spades, tricks: 8}
  end

  test "determine highest bid with suits" do
    bids = [
      %Bid{suit: :spades, tricks: 6},
      %Bid{suit: :diamonds, tricks: 6},
      %Bid{suit: :hearts, tricks: 6}
    ]

    assert Game.highest_bid(bids) == %Bid{suit: :hearts, tricks: 6}
  end
end
