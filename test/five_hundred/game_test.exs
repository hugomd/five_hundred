defmodule FiveHundred.GameTest do
  use ExUnit.Case

  alias FiveHundred.{Bid, Game, Player, PlayerBid}

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

  test "cannot bid multiple times" do
    
  end

  test "cannot bid out of order" do
  end

  test "bid must be a standard bid" do
  end

  test "previous winner must bid" do
    player1 = %Player{name: "Han Solo", hand: []}
    player2 = %Player{name: "Obi-wan Kenobi", hand: []}

    {:ok, game} = Game.new_game(player2, 2)
           |> Game.join_game(player1)
    bid = %PlayerBid{
      player: player1, 
      bid: %Bid{name: "6 spades", points: 40, suit: :spades, tricks: 6}
    }

    result = Game.bid(game, bid)
    assert result == {:error, :last_round_winner_must_bid_first}
  end

  test "previous winner bids successfully" do
    player1 = %Player{name: "Han Solo", hand: []}
    player2 = %Player{name: "Obi-wan Kenobi", hand: []}

    {:ok, game} = Game.new_game(player1, 2)
           |> Game.join_game(player2)
    bid = %PlayerBid{
      player: player1, 
      bid: %Bid{name: "6 spades", points: 40, suit: :spades, tricks: 6}
    }

    {:ok, %{winning_bid: winning_bid}} = Game.bid(game, bid)
    assert winning_bid == bid
  end
end
