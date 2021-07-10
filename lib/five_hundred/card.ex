defmodule FiveHundred.Card do
  @doc """
  Models a card from a standard 53 card deck
  """

  @derive Jason.Encoder
  defstruct [:rank, :suit]
  alias FiveHundred.Card

  @type t :: %Card{rank: rank, suit: suit}
  @type suit :: :no_trumps | :hearts | :diamonds | :clubs | :spades | :joker
  @type rank :: 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15

  @spec suits() :: [suit]
  def suits(), do: [:no_trumps, :hearts, :diamonds, :clubs, :spades]

  @spec traditional_suits() :: [suit]
  def traditional_suits(), do: [:hearts, :diamonds, :clubs, :spades]

  @spec ranks() :: [rank]
  def ranks(), do: Enum.to_list(2..14)

  @spec joker() :: t()
  def joker(), do: %Card{rank: 15, suit: :joker}

  @spec to_string(suit()) :: String.t()
  def to_string(suit),
    do:
      suit
      |> Atom.to_string()
      |> String.replace(~r/_/, " ")
      |> String.split(" ")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")
end
