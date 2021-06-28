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
    :state,
    :bid,
    :players
  ]

  @type state :: :bidding | :playing | :waiting_for_players

  @type t :: %Game{
          state: state,
          bid: Bid.t(),
          players: [Player.t()]
        }

  @spec highest_bid([Bid.t()]) :: Bid.t()
  def highest_bid(bids),
    do:
      bids
      |> Bid.sort_by_points()
      |> hd
end
