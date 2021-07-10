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

  test "joins a game" do
    player1 = %Player{name: "Han Solo", hand: []}
    player2 = %Player{name: "Obi-wan Kenobi", hand: []}
    game = Game.new_game(player1, 2)

    {:ok, result} = Game.join_game(game, player2)
    assert result.players == [player2, player1]
    assert result.state == :bidding
  end

  test "cannot have more than max_players" do
    player1 = %Player{name: "Han Solo", hand: []}
    player2 = %Player{name: "Obi-wan Kenobi", hand: []}
    game = Game.new_game(player1, 1)

    result = Game.join_game(game, player2)

    assert result == {:error, :max_players}
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
