defmodule FiveHundred.Bid do
  @derive Jason.Encoder
  defstruct [:suit, :tricks]
  alias FiveHundred.{Bid, Card}

  @type t :: %Bid{
    suit: Card.suit(),
    tricks: integer
  }
end
