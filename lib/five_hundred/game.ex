defmodule FiveHundred.Game do
  @moduledoc """
  Models a game of 500

  TODO: 
  - score
  - turn
  """
  alias FiveHundred.{Bid, Game, Player}

  @derive Jason.Encoder
  defstruct [
    :bids,
    :winning_bid,
    :players,
    :player_turn,
    :code,
    :max_players,
    state: :waiting_for_players
  ]

  @type code :: String.t()
  @type state :: :bidding | :playing | :waiting_for_players | :finished

  @type t :: %Game{
          bids: nil | [Bid.t()],
          code: nil | code(),
          players: [Player.t()],
          player_turn: nil | integer(),
          state: state,
          winning_bid: nil | Bid.t(),
          max_players: integer()
        }

  @spec new_game(Player.t()) :: t()
  def new_game(%Player{} = player, max_players \\ 4),
    do: %Game{
      code: code(),
      players: [player],
      max_players: max_players
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
  @spec bid(t(), Player.t(), Bid.t()) :: nil | {:error, :max_bids}
  def bid(%Game{bids: bids, max_players: max_players}, %Player{}, %Bid{})
      when length(bids) == max_players,
      do: {:error, :max_bids}

  def bid(%Game{bids: []} = game, %Player{} = player, %Bid{} = bid) do
    # Bid must be in list of standard bids
    # If there is a previous winner, ensure they bid first, then around the table from them.
    # E.g. Table: 1, 2, 3, 4. Last winner was 3, then the bids should be 3, 4, 1, 2
    # If there is no previous winner, assume the previous winner to the first player who joined
  end

  @spec ready_for_bidding?({:ok, t()}) :: {:ok, t()}
  def ready_for_bidding?({:ok, %Game{players: players, max_players: max_players} = game})
      when length(players) == max_players,
      do: {:ok, %Game{game | state: :bidding}}

  def ready_for_bidding?({:ok, %Game{} = game}), do: {:ok, game}

  @spec highest_bid([Bid.t()]) :: Bid.t()
  def highest_bid(bids),
    do:
      bids
      |> Bid.sort_by_points()
      |> hd

  def code(length \\ 5),
    do:
      :crypto.strong_rand_bytes(length)
      |> Base.url_encode64()
      |> binary_part(0, length)
      |> String.upcase()
end
