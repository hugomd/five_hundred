defmodule FiveHundred.PlayerBid do
  @moduledoc """
  Associates a player by index with their bid
  """
  @derive Jason.Encoder
  defstruct [:player_index, :bid]
  alias FiveHundred.{PlayerBid, Bid, Player}

  @type t :: %PlayerBid{
          player_index: integer(),
          bid: Bid.t()
        }
end
