defmodule FiveHundred.Player do
  @moduledoc """
  Models a player in 500.
  """

  alias FiveHundred.{Card, Player}

  @derive Jason.Encoder
  # TODO: Should we store the player index here?
  defstruct [
    :name,
    hand: []
  ]

  @type t :: %Player{
          name: nil | String.t(),
          hand: nil | [Card.t()]
        }
end
