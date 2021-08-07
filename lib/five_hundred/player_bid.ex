defmodule FiveHundred.PlayerBid do
  @derive Jason.Encoder
  defstruct [:player, :bid]
  alias FiveHundred.{PlayerBid, Bid, Player}

  @type t :: %PlayerBid{
    player: Player.t(),
    bid: Bid.t()
  }
end
