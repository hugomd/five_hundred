defmodule FiveHundred.Game do
  @moduledoc """
  Models a game of 500
  """
  alias FiveHundred.{Bid, Card, Deck, Game}

  # TODO: score, players, turn, bid
  @derive Jason.Encoder
  defstruct [
    :state,
    :bid
  ]

  @type state :: :bidding | :playing
  
  @type t :: %Game{
    state: state,
    bid: Bid.t()
  }
end
