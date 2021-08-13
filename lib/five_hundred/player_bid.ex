defmodule FiveHundred.PlayerBid do
  @derive Jason.Encoder
  defstruct [:player_index, :bid]
  alias FiveHundred.{PlayerBid, Bid, Player}

  @type t :: %PlayerBid{
          player_index: integer(),
          bid: Bid.t()
        }
end
