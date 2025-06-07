defmodule FiveHundred.Game do
  @moduledoc """
  Models a game of 500
  """
  alias FiveHundred.{Bid, Game, Player, PlayerBid, Card}
  require Logger

  @derive Jason.Encoder
  defstruct [
    :winning_bid,
    :players,
    :turn,
    :game_code,
    :max_players,
    :last_round_winner,
    :bid_exclusion,
    :current_trick,
    :tricks_won,
    :trick_leader,
    :team_scores,
    :tricks_per_team,
    :kitty,
    # Track game history
    decisions: [],
    state: :waiting_for_players
  ]

  @type game_code :: String.t()
  @type state :: :bidding | :exchanging | :playing | :waiting_for_players | :finished
  @type decision :: String.t() | map()

  @type t :: %Game{
          game_code: nil | game_code(),
          players: [Player.t()],
          turn: nil | integer(),
          state: state,
          winning_bid: nil | PlayerBid.t(),
          max_players: integer(),
          bid_exclusion: [integer()],
          last_round_winner: nil | integer(),
         current_trick: [Card.t()],
         tricks_won: non_neg_integer(),
          trick_leader: nil | integer(),
          team_scores: %{non_neg_integer() => integer()},
          tricks_per_team: %{non_neg_integer() => non_neg_integer()},
          kitty: [Card.t()],
          decisions: [decision()]
        }

  @spec new_game(Player.t(), game_code()) :: t()
  def new_game(%Player{} = player, game_code, max_players \\ 4) do
    %Game{
      game_code: game_code,
      # First player will be index 0
      players: [player],
      max_players: max_players,
      last_round_winner: 0,
      turn: 0,
      bid_exclusion: [],
      winning_bid: nil,
      current_trick: [],
      tricks_won: 0,
      trick_leader: 0,
      # Team 0 is players 0,2; Team 1 is players 1,3
      team_scores: %{0 => 0, 1 => 0},
      tricks_per_team: %{0 => 0, 1 => 0},
      kitty: [],
      decisions: []
    }
  end

  @spec join_game(t(), Player.t()) :: {:ok, t()} | {:error, :max_players}
  def join_game(%Game{players: players} = game, %Player{})
      when length(players) == game.max_players,
      do: {:error, :max_players}

  def join_game(%Game{players: players} = game, %Player{} = player) do
    # Append new player to end of list to maintain correct player indices
    {:ok, game} = {:ok, %Game{game | players: players ++ [player]}}

    case length(players) + 1 == game.max_players do
      true -> {:ok, %Game{game | state: :bidding}}
      false -> {:ok, game}
    end
  end

  @spec bid(t(), PlayerBid.t()) ::
          {:ok, t()}
          | {:error,
             :last_round_winner_must_bid_first | :not_bidding | :bid_not_high_enough | :cannot_bid}
  def bid(%Game{} = game, %PlayerBid{player_index: player_index} = playerBid) do
    Logger.debug("""
    ===== Bid Received =====
    From player: #{player_index}
    Current turn: #{game.turn}
    Bid value: #{inspect(playerBid.bid)}
    Excluded: #{inspect(game.bid_exclusion)}
    Is last player? #{length(game.bid_exclusion) == length(game.players) - 1}
    =====================
    """)

    with {:ok, game} <- ensure_bidding(game),
         {:ok, game} <- ensure_last_winner_has_bid_first(game, playerBid),
         {:ok, game} <- ensure_turn(game, player_index),
         {:ok, game} <- ensure_can_bid(game, player_index),
         {:ok, game} <- ensure_bid_is_higher(game, playerBid),
         {:ok, game} <- set_winning_bid(game, playerBid) do
      # Record the bid decision
      player = Enum.at(game.players, player_index)
      decision = "Player #{player_index + 1} (#{player.name}) bid #{playerBid.bid.name}"
      game = %Game{game | decisions: [decision | game.decisions]}

      # If this is the last player and they made a valid bid, they win and we deal
      if length(game.bid_exclusion) == length(game.players) - 1 do
        Logger.debug("Last player made a bid - they win and we deal")

        winning_decision =
          "Player #{player_index + 1} (#{player.name}) won bidding with #{playerBid.bid.name}"

        game = %Game{game | decisions: [winning_decision | game.decisions]}
        {:ok, game} = deal_cards(game)
        {:ok, game}
      else
        # Otherwise continue bidding
        {:ok, game} = exclude_from_bidding(game, player_index)
        {:ok, %Game{state: new_state} = game} = bid_advance(game)

        # Only advance turn if still bidding
        game =
          if new_state == :bidding do
            {:ok, game} = advance_turn(game)
            game
          else
            game
          end

        Logger.debug("""
        ===== Bid Accepted =====
        New turn: #{game.turn}
        Excluded: #{inspect(game.bid_exclusion)}
        Winner: #{inspect(game.winning_bid)}
        State: #{game.state}
        ====================
        """)

        {:ok, game}
      end
    else
      error ->
        Logger.debug("Bid rejected: #{inspect(error)}")
        error
    end
  end

  @spec pass(t(), integer()) :: {:ok, t()} | {:error, :not_your_turn | :not_bidding | :must_bid}
  def pass(%Game{} = game, player_index) do
    Logger.debug("""
    ===== Pass Received =====
    From player: #{player_index}
    Current turn: #{game.turn}
    Excluded: #{inspect(game.bid_exclusion)}
    Winning bid: #{inspect(game.winning_bid)}
    Remaining players: #{length(game.players) - length(game.bid_exclusion)}
    =====================
    """)

    # Check if this is the last player and no current bid - they must bid in this case
    remaining_players = length(game.players) - length(game.bid_exclusion)
    must_bid = remaining_players == 1 && is_nil(game.winning_bid)

    with {:ok, game} <- ensure_bidding(game),
         {:ok, _} <- ensure_turn(game, player_index),
         {:ok, _} <- ensure_can_bid(game, player_index),
         {:ok, _} <- if(must_bid, do: {:error, :must_bid}, else: {:ok, game}),
         {:ok, game} <- exclude_from_bidding(game, player_index),
         {:ok, %Game{state: new_state} = game} <- bid_advance(game) do
      Logger.debug(
        "Pass - player #{player_index} added to exclusion list: #{inspect(game.bid_exclusion)}"
      )

      player = Enum.at(game.players, player_index)
      decision = "Player #{player_index + 1} (#{player.name}) passed"
      game = %Game{game | decisions: [decision | game.decisions]}

      remaining_player =
        if length(game.bid_exclusion) == length(game.players) - 1 do
          Enum.find_index(0..(length(game.players) - 1), fn i ->
            i not in game.bid_exclusion
          end)
        end

      game =
        cond do
          length(game.bid_exclusion) == 4 ->
            {:ok, game} = deal_cards(game)
            game

          new_state != :bidding ->
            Logger.debug("Pass - not changing turn since state is #{new_state}")
            game

          remaining_player != nil ->
            Logger.debug("Pass - setting turn to remaining player #{remaining_player}")
            %Game{game | turn: remaining_player}

          true ->
            {:ok, game} = advance_turn(game)
            Logger.debug("Pass - advanced turn to next player #{game.turn}")
            game
        end

      Logger.debug("""
      ===== Pass Accepted =====
      New turn: #{game.turn}
      Excluded: #{inspect(game.bid_exclusion)}
      Winner: #{inspect(game.winning_bid)}
      State: #{game.state}
      ====================
      """)

      {:ok, game}
    else
      error ->
        Logger.debug("Pass rejected: #{inspect(error)}")
        error
    end
  end

  @spec play_card(t(), integer(), Card.t()) :: {:ok, t()} | {:error, atom()}
  def play_card(%Game{state: :playing} = game, player_index, card) do
    Logger.debug("""
    ===== Play Card =====
    From player: #{player_index}
    Current turn: #{game.turn}
    Card: #{inspect(card)}
    Current trick: #{inspect(game.current_trick)}
    Tricks won: #{game.tricks_won}
    ===================
    """)

    with {:ok, game} <- ensure_turn(game, player_index),
         {:ok, game} <- ensure_valid_card(game, player_index, card),
         {:ok, game} <- add_card_to_trick(game, card),
         {:ok, game} <- check_trick_complete(game),
         {:ok, game} <- check_round_complete(game) do
      # Record the play decision
      player = Enum.at(game.players, player_index)
      decision = "Player #{player_index + 1} (#{player.name}) played #{display_card(card)}"
      game = %Game{game | decisions: [decision | game.decisions]}

      Logger.debug("""
      ===== Card Played =====
      New turn: #{game.turn}
      Current trick: #{inspect(game.current_trick)}
      Tricks won: #{game.tricks_won}
      State: #{game.state}
      Team scores: #{inspect(game.team_scores)}
      Tricks per team: #{inspect(game.tricks_per_team)}
      ====================
      """)

      {:ok, game}
    else
      error ->
        Logger.debug("Card play rejected: #{inspect(error)}")
        error
    end
  end

  def play_card(_game, _player_index, _card), do: {:error, :not_playing}

  @spec exchange_card(t(), integer(), Card.t(), Card.t()) :: {:ok, t()} | {:error, atom()}
  def exchange_card(%Game{state: :exchanging} = game, player_index, kitty_card, hand_card) do
    with {:ok, game} <- ensure_winner(game, player_index),
         {:ok, game} <- validate_exchange(game, kitty_card, hand_card),
         {:ok, game} <- perform_exchange(game, player_index, kitty_card, hand_card) do
      # Record the exchange without revealing card details
      player = Enum.at(game.players, player_index)

      decision =
        "Player #{player_index + 1} (#{player.name}) exchanged with the kitty"

      {:ok, %Game{game | decisions: [decision | game.decisions]}}
    end
  end

  def exchange_card(_game, _player_index, _kitty_card, _hand_card),
    do: {:error, :not_exchanging}

  @spec complete_exchange(t()) :: {:ok, t()} | {:error, atom()}
  def complete_exchange(
        %Game{state: :exchanging, winning_bid: %PlayerBid{player_index: winner_index}} = game
      ) do
    # Record that kitty exchange is complete
    player = Enum.at(game.players, winner_index)
    decision = "Player #{winner_index + 1} (#{player.name}) completed kitty exchange"
    game = %Game{game | decisions: [decision | game.decisions]}

    {:ok,
     %Game{
       game
       | state: :playing,
         # Winning bidder goes first
         turn: winner_index,
         # Clear kitty after exchange
         kitty: []
     }}
  end

  def complete_exchange(_game), do: {:error, :not_exchanging}

  # Private functions

  @spec ensure_winner(t(), integer()) :: {:ok, t()} | {:error, :not_winner}
  defp ensure_winner(
         %Game{winning_bid: %PlayerBid{player_index: winner_index}} = game,
         player_index
       )
       when winner_index == player_index,
       do: {:ok, game}

  defp ensure_winner(_game, _player_index),
    do: {:error, :not_winner}

  @spec validate_exchange(t(), Card.t(), Card.t()) :: {:ok, t()} | {:error, atom()}
  defp validate_exchange(
         %Game{
           kitty: kitty,
           players: players,
           winning_bid: %PlayerBid{player_index: winner_index}
         } = game,
         kitty_card,
         hand_card
       ) do
    player = Enum.at(players, winner_index)

    cond do
      kitty_card not in kitty ->
        {:error, :invalid_kitty_card}

      hand_card not in player.hand ->
        {:error, :invalid_hand_card}

      true ->
        {:ok, game}
    end
  end

  @spec perform_exchange(t(), integer(), Card.t(), Card.t()) :: {:ok, t()}
  defp perform_exchange(
         %Game{kitty: kitty, players: players} = game,
         player_index,
         kitty_card,
         hand_card
       ) do
    # Update player's hand
    player = Enum.at(players, player_index)

    updated_hand =
      player.hand
      |> List.delete(hand_card)
      |> List.insert_at(0, kitty_card)

    updated_player = %Player{player | hand: updated_hand}
    updated_players = List.replace_at(players, player_index, updated_player)

    # Update kitty
    updated_kitty =
      kitty
      |> List.delete(kitty_card)
      |> List.insert_at(0, hand_card)

    {:ok, %Game{game | players: updated_players, kitty: updated_kitty}}
  end

  @spec ensure_valid_card(t(), integer(), Card.t()) :: {:ok, t()} | {:error, atom()}
  defp ensure_valid_card(%Game{players: players} = game, player_index, card) do
    player = Enum.at(players, player_index)

    cond do
      card not in player.hand ->
        {:error, :card_not_in_hand}

      not follows_suit_rules?(game, card, player) ->
        {:error, :must_follow_suit}

      true ->
        # Remove the card from the player's hand
        updated_player = %Player{player | hand: List.delete(player.hand, card)}
        updated_players = List.replace_at(players, player_index, updated_player)
        {:ok, %Game{game | players: updated_players}}
    end
  end

  # Check if a card follows suit rules
  defp follows_suit_rules?(%Game{current_trick: []}, _card, _player), do: true

  defp follows_suit_rules?(%Game{current_trick: [first | _]} = game, %Card{suit: suit}, player) do
    led_suit = first.suit

    # If player has the led suit, they must play it
    # Unless card is a trump, trumps can always be played
    suit == led_suit or
      not has_suit?(player, led_suit) or
      suit == game.winning_bid.bid.suit
  end

  defp has_suit?(%Player{hand: hand}, suit),
    do: Enum.any?(hand, &(&1.suit == suit))

  @spec add_card_to_trick(t(), Card.t()) :: {:ok, t()}
  defp add_card_to_trick(%Game{current_trick: trick} = game, card) do
    {:ok, %Game{game | current_trick: trick ++ [card]}}
  end

  @spec check_trick_complete(t()) :: {:ok, t()}
  defp check_trick_complete(%Game{current_trick: trick, players: players} = game)
       when length(trick) == length(players) do
    winner_index = determine_trick_winner(game)
    winner = Enum.at(game.players, winner_index)
    winning_team = rem(winner_index, 2)
    last_card = List.last(trick)

    # Record who won the trick and with what card
    cards_played = Enum.map_join(trick, ", ", &display_card/1)

    Logger.debug("""
    ===== Trick Complete =====
    Winner: Player #{winner_index + 1} (#{winner.name})
    Winning team: #{winning_team}
    Trick cards: #{cards_played}
    ======================
    """)

    updated_tricks_per_team = Map.update!(game.tricks_per_team, winning_team, &(&1 + 1))
    trick_points = updated_tricks_per_team[winning_team] * 10

    trick_decision = %{
      type: :trick_complete,
      cards: trick,
      leader: game.trick_leader,
      winner: winner_index,
      winner_card: last_card,
      team: winning_team,
      points: trick_points
    }

    {:ok,
     %Game{
       game
       | current_trick: [],
         tricks_won: game.tricks_won + 1,
         # Winner leads next trick
         turn: winner_index,
         trick_leader: winner_index,
         tricks_per_team: updated_tricks_per_team,
         decisions: [trick_decision | game.decisions]
     }}
  end

  defp check_trick_complete(%Game{} = game) do
    Logger.debug("Trick not complete - advancing to next player")
    {:ok, %Game{game | turn: rem(game.turn + 1, length(game.players))}}
  end

  @spec check_round_complete(t()) :: {:ok, t()}
  defp check_round_complete(%Game{tricks_won: tricks_won} = game)
       # Each round has exactly 10 tricks
       when tricks_won == 10 do
    # Round is complete, score it
    updated_game = score_round(game)

    # Add round completion decision
    winning_bid = updated_game.winning_bid
    winner = Enum.at(updated_game.players, winning_bid.player_index)
    team_id = rem(winning_bid.player_index, 2)
    tricks_taken = updated_game.tricks_per_team[team_id]

    decision =
      if tricks_taken >= winning_bid.bid.tricks do
        "Round complete - Player #{winning_bid.player_index + 1} (#{winner.name}) made contract with #{tricks_taken} tricks"
      else
        "Round complete - Player #{winning_bid.player_index + 1} (#{winner.name}) failed contract with #{tricks_taken} tricks"
      end

    game_after_round = %Game{updated_game | decisions: [decision | updated_game.decisions]}
    finished_game = maybe_finish_game(game_after_round)

    if finished_game.state == :finished do
      {:ok, finished_game}
    else
      # Reset for next round
      {:ok,
       %Game{
         finished_game
         | state: :bidding,
           tricks_won: 0,
           current_trick: [],
           winning_bid: nil,
           bid_exclusion: [],
           tricks_per_team: %{0 => 0, 1 => 0},
           turn: finished_game.last_round_winner
       }}
    end
  end

  defp check_round_complete(%Game{} = game), do: {:ok, game}

  @spec score_round(t()) :: t()
  defp score_round(%Game{winning_bid: %PlayerBid{player_index: winner_index, bid: bid}} = game) do
    winning_team = rem(winner_index, 2)
    tricks_needed = bid.tricks
    tricks_taken = game.tricks_per_team[winning_team]

    points =
      cond do
        tricks_taken >= tricks_needed ->
          # Made contract
          bid.points

        true ->
          # Failed contract
          -bid.points
      end

    %Game{
      game
      | team_scores: Map.update!(game.team_scores, winning_team, &(&1 + points)),
        # Winner/loser leads next round
        last_round_winner: winner_index
    }
  end

  @spec maybe_finish_game(t()) :: t()
  defp maybe_finish_game(%Game{team_scores: %{0 => score0, 1 => score1}} = game) do
    cond do
      score0 >= 500 ->
        %Game{game | state: :finished, decisions: ["Team 1 wins the game with #{score0} points" | game.decisions]}

      score1 >= 500 ->
        %Game{game | state: :finished, decisions: ["Team 2 wins the game with #{score1} points" | game.decisions]}

      score0 <= -500 ->
        %Game{game | state: :finished, decisions: ["Team 1 loses the game with #{score0} points" | game.decisions]}

      score1 <= -500 ->
        %Game{game | state: :finished, decisions: ["Team 2 loses the game with #{score1} points" | game.decisions]}

      true ->
        game
    end
  end

  @spec determine_trick_winner(t()) :: integer()
  defp determine_trick_winner(
         %Game{
           current_trick: trick,
           trick_leader: leader,
           winning_bid: %PlayerBid{bid: %Bid{suit: trump_suit}}
         } = game
       ) do
    led_suit = Enum.at(trick, 0).suit

    # Compare each card in the trick considering trump suit
    {_winning_card, winner_offset} =
      trick
      |> Enum.with_index()
      |> Enum.max_by(fn {card, _i} -> card_value(card, led_suit, trump_suit) end)

    rem(leader + winner_offset, length(game.players))
  end

  @spec card_value(Card.t(), Card.suit(), Card.suit()) :: integer()
  defp card_value(%Card{suit: suit, rank: rank}, led_suit, trump_suit) do
    cond do
      suit == :joker -> 1000
      # Trumps beat non-trumps
      suit == trump_suit -> rank + 100
      # Following suit ranks normally
      suit == led_suit -> rank
      # Off-suit cards can't win
      true -> 0
    end
  end

  @spec bid_advance(t()) :: {:ok, t()}
  def bid_advance(
        %Game{bid_exclusion: bid_exclusion, players: players, winning_bid: winning_bid} = game
      )
      # All but one player has passed
      when length(bid_exclusion) == length(players) - 1 do
    # Find the player who hasn't passed
    remaining_player =
      Enum.find_index(0..(length(players) - 1), fn i -> i not in bid_exclusion end)

    Logger.debug("""
    ===== Bid Advance - Last Player Check =====
    Players: #{length(players)}
    Excluded (#{length(bid_exclusion)}): #{inspect(bid_exclusion)}
    Current turn: #{game.turn}
    Remaining player: #{remaining_player}
    Has remaining player passed? #{remaining_player in bid_exclusion}
    =====================================
    """)

    cond do
      # Current bid exists and remaining player passed - winner is current highest bid
      remaining_player in bid_exclusion ->
        Logger.debug("Remaining player passed - player #{winning_bid.player_index} wins")
        {:ok, game} = deal_cards(game)
        {:ok, game}

      # If no winning bid exists, remaining player must bid
      is_nil(winning_bid) ->
        Logger.debug("No current bid - remaining player #{remaining_player} must make a bid")
        {:ok, game}

      # Otherwise remaining player must bid or pass
      true ->
        Logger.debug("Remaining player #{remaining_player} must bid or pass")
        {:ok, game}
    end
  end

  def bid_advance(%Game{} = game) do
    Logger.debug("Regular bid advance - continuing bidding")
    {:ok, game}
  end

  @spec deal_cards(t()) :: {:ok, t()}
  defp deal_cards(
         %Game{players: players, winning_bid: %PlayerBid{player_index: winner_index}} = game
       ) do
    Logger.debug("Dealing cards - winner is player #{winner_index + 1}")
    deck = FiveHundred.Deck.new_shuffled()

    # Deal 3 cards to kitty first
    {kitty, remaining_deck} = Enum.split(deck, 3)

    # Deal remaining cards to players
    cards_per_player = div(length(remaining_deck), length(players))
    hands = Enum.chunk_every(remaining_deck, cards_per_player)

    players_with_hands =
      Enum.zip(players, hands)
      |> Enum.map(fn {player, hand} -> %Player{player | hand: hand} end)

    {:ok,
     %Game{
       game
       | players: players_with_hands,
         kitty: kitty,
         # Set turn to winning player
         turn: winner_index,
         state: :exchanging
     }}
  end

  @spec ensure_bidding(t()) :: {:ok, t()} | {:error, :not_bidding}
  def ensure_bidding(%Game{state: state}) when state != :bidding,
    do: {:error, :not_bidding}

  def ensure_bidding(%Game{} = game), do: {:ok, game}

  @spec ensure_turn(t(), integer()) :: {:ok, t()} | {:error, :not_your_turn}
  def ensure_turn(%Game{turn: turn}, player_index) when turn != player_index,
    do: {:error, :not_your_turn}

  def ensure_turn(%Game{} = game, _player_index), do: {:ok, game}

  @spec ensure_last_winner_has_bid_first(t(), PlayerBid.t()) ::
          {:ok, t()} | {:error, :last_round_winner_must_bid_first}
  def ensure_last_winner_has_bid_first(
        %Game{
          winning_bid: nil,
          last_round_winner: last_round_winner,
          bid_exclusion: bid_exclusion
        } = game,
        %PlayerBid{player_index: player_index}
      ) do
    cond do
      Enum.member?(bid_exclusion, last_round_winner) ->
        {:ok, game}

      player_index != last_round_winner ->
        {:error, :last_round_winner_must_bid_first}

      true ->
        {:ok, game}
    end
  end

  def ensure_last_winner_has_bid_first(%Game{} = game, %PlayerBid{}), do: {:ok, game}

  @spec ensure_bid_is_higher(t(), PlayerBid.t()) :: {:ok, t()} | {:error, :bid_not_high_enough}
  def ensure_bid_is_higher(%Game{winning_bid: nil} = game, %PlayerBid{}), do: {:ok, game}

  def ensure_bid_is_higher(
        %Game{winning_bid: %PlayerBid{bid: winning_bid}} = game,
        %PlayerBid{bid: new_bid} = playerBid
      ) do
    case Bid.compare(new_bid, winning_bid) do
      :gt -> set_winning_bid(game, playerBid)
      _ -> {:error, :bid_not_high_enough}
    end
  end

  @spec ensure_can_bid(t(), integer()) :: {:ok, t()} | {:error, :cannot_bid}
  def ensure_can_bid(%Game{bid_exclusion: bid_exclusion} = game, player_index) do
    if Enum.member?(bid_exclusion, player_index) do
      {:error, :cannot_bid}
    else
      {:ok, game}
    end
  end

  @spec set_winning_bid(t(), PlayerBid.t()) :: {:ok, t()}
  def set_winning_bid(%Game{} = game, %PlayerBid{} = playerBid),
    do: {:ok, %Game{game | winning_bid: playerBid}}

  @spec exclude_from_bidding(t(), integer()) :: {:ok, t()}
  def exclude_from_bidding(%Game{bid_exclusion: bid_exclusion} = game, player_index),
    do: {:ok, %Game{game | bid_exclusion: [player_index | bid_exclusion]}}

  @spec advance_turn(t()) :: {:ok, t()}
  def advance_turn(%Game{players: players, turn: current_turn} = game),
    do: {:ok, %Game{game | turn: rem(current_turn + 1, length(players))}}

  @spec game_code(integer) :: String.t()
  def game_code(length \\ 5),
    do:
      :crypto.strong_rand_bytes(length)
      |> Base.url_encode64()
      |> binary_part(0, length)
      |> String.upcase()

  @spec get_player(t(), String.t()) :: {:ok, Player.t()} | {:error, :unknown_player}
  def get_player(game, id) do
    game.players
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> {:error, :unknown_player}
      player -> {:ok, player}
    end
  end

  def display_card(%Card{rank: 15, suit: :joker}), do: "🃏"

  def display_card(%Card{rank: rank, suit: suit}) do
    suit_symbol =
      case suit do
        :hearts -> "♥"
        :diamonds -> "♦"
        :clubs -> "♣"
        :spades -> "♠"
        _ -> "?"
      end

    rank_symbol =
      case rank do
        11 -> "J"
        12 -> "Q"
        13 -> "K"
        14 -> "A"
        n -> to_string(n)
      end

    rank_symbol <> suit_symbol
  end

  @spec last_completed_trick(t()) :: {list(Card.t()), integer()} | nil
  def last_completed_trick(%Game{decisions: decisions}) do
    Enum.find_value(decisions, fn
      %{type: :trick_complete, cards: cards, leader: leader} -> {cards, leader}
      _ -> nil
    end)
  end

  @spec decision_to_string(t(), decision()) :: String.t()
  def decision_to_string(_game, decision) when is_binary(decision), do: decision

  def decision_to_string(game, %{type: :trick_complete, winner: winner, winner_card: card, team: team, points: points}) do
    player = Enum.at(game.players, winner)
    "Player #{winner + 1} (#{player.name}) won the trick with #{display_card(card)}. Team #{team + 1} has #{points} points"
  end
end
