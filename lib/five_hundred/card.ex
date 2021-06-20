defmodule FiveHundred.Card do
  """
  @doc
  Cards have a rank and a suit.
  """

  @derive Jason.Encoder
  defstruct [:rank, :suit]

  alias FiveHundred.Card

  def suits(), do: [:hearts, :diamonds, :clubs, :spades]
  def ranks(), do: Enum.to_list(2..14)
  def joker(), do: %Card{rank: 15, suit: :joker}
end
