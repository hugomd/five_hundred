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

  @spec join_game(t(), Player.t()) :: t()
  def join_game(%Game{players: players} = game, %Player{})
      when length(players) == game.max_players,
      do: {:error, :max_players}

  def join_game(%Game{players: players} = game, %Player{} = player) do
    {:ok, %Game{game | players: [player | players]}}
    |> ready_for_bidding?
  end

  @spec ready_for_bidding?(t()) :: t()
  def ready_for_bidding?({:ok, %Game{players: players, max_players: max_players} = game})
      when length(players) == max_players,
      do: {:ok, %Game{game | state: :bidding}}

  def ready_for_bidding?({:ok, %Game{}} = game), do: game

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
