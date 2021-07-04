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
    :bid,
    :players,
    :player_turn,
    :code,
    state: :waiting_for_players
  ]

  @type code :: String.t()
  @type state :: :bidding | :playing | :waiting_for_players | :finished

  @type t :: %Game{
          state: state,
          bid: Bid.t(),
          players: [Player.t()],
          player_turn: nil | integer(),
          code: code()
        }

  @spec new_game(Player.t()) :: t()
  def new_game(%Player{} = player),
    do: %Game{
      code: code(),
      players: [player]
    }

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
