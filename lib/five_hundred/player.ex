defmodule FiveHundred.Player do
  @moduledoc """
  Models a player in 500.
  """

  alias FiveHundred.{Card, Player}

  @derive Jason.Encoder
  defstruct [
    :name,
    :hand
  ]

  @type t :: %Player{
    name: String.t(),
    hand: [Card.t()]
  }
end
