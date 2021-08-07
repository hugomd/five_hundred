defmodule FiveHundred.Game do
  @moduledoc """
  Models a game of 500

  TODO: 
  - score
  - turn
  """
  alias FiveHundred.{Bid, Game, Player, PlayerBid}

  @derive Jason.Encoder
  defstruct [
    :winning_bid,
    :players,
    :player_turn,
    :code,
    :max_players,
    :last_round_winner,
    state: :waiting_for_players
  ]

  @type code :: String.t()
  @type state :: :bidding | :playing | :waiting_for_players | :finished

  @type t :: %Game{
          code: nil | code(),
          players: [Player.t()],
          player_turn: nil | integer(),
          state: state,
          winning_bid: nil | PlayerBid.t(),
          max_players: integer(),
          last_round_winner: nil | Player.t()
        }

  @spec new_game(Player.t()) :: t()
  def new_game(%Player{} = player, max_players \\ 4),
    do: %Game{
      code: code(),
      players: [player],
      max_players: max_players,
      last_round_winner: player,
      winning_bid: nil
    }

  @spec join_game(t(), Player.t()) :: {:ok, t()} | {:error, :max_players}
  def join_game(%Game{players: players} = game, %Player{})
      when length(players) == game.max_players,
      do: {:error, :max_players}

  def join_game(%Game{players: players} = game, %Player{} = player) do
    {:ok, %Game{game | players: [player | players]}}
    |> ready_for_bidding?
  end

  # Bids go around the table, starting left of the dealer
  @spec bid(t(), PlayerBid.t()) :: {:ok, %Game{}} | {:error, :last_round_winner_must_bid_first | :not_bidding | :bid_not_high_enough}
  def bid(%Game{state: state}) when state != :bidding, do: {:error, :not_bidding}

  def bid(%Game{winning_bid: nil, last_round_winner: last_round_winner}, %PlayerBid{player: player})
    when last_round_winner != player,
    do: {:error, :last_round_winner_must_bid_first}
  def bid(%Game{winning_bid: nil} = game, %PlayerBid{} = playerBid),
    do: {:ok, %Game{game | winning_bid: playerBid}}

  # TODO: bid in order, use a tuple of player and bid

  def bid(%Game{winning_bid: %PlayerBid{bid: winning_bid}} = game, %PlayerBid{bid: new_bid} = playerBid) do
    case Bid.compare(new_bid, winning_bid) do
      :gt -> {:ok, %Game{game | winning_bid: playerBid}}
      _ -> {:error, :bid_not_high_enough}
    end
  end

  @spec ready_for_bidding?({:ok, t()}) :: {:ok, t()}
  def ready_for_bidding?({:ok, %Game{players: players, max_players: max_players} = game})
      when length(players) == max_players,
      do: {:ok, %Game{game | state: :bidding}}

  def ready_for_bidding?({:ok, %Game{} = game}), do: {:ok, game}

  def code(length \\ 5),
    do:
      :crypto.strong_rand_bytes(length)
      |> Base.url_encode64()
      |> binary_part(0, length)
      |> String.upcase()
end
