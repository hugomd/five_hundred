defmodule FiveHundred.GameTest do
  use ExUnit.Case

  alias FiveHundred.{Bid, Game, Player}

  test "creates a new game" do
    player = %Player{name: "Han Solo", hand: []}
    game = Game.new_game(player)

    assert game.players == [player]
    assert game.code != nil
    assert game.state == :waiting_for_players
  end

  test "determine highest bid" do
    bids = [
      %Bid{name: "6 spades", points: 40, suit: :spades, tricks: 6},
      %Bid{name: "6 hearts", points: 160, suit: :hearts, tricks: 6},
      %Bid{name: "8 spades", points: 80, suit: :spades, tricks: 8},
      %Bid{name: "7 diamonds", points: 180, suit: :diamonds, tricks: 7}
    ]

    assert Game.highest_bid(bids) == %Bid{
             name: "7 diamonds",
             points: 180,
             suit: :diamonds,
             tricks: 7
           }
  end
end
