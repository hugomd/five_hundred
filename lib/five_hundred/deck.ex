defmodule FiveHundred.Deck do
  @moduledoc """
  Models a four-handed 500 deck
  """
  alias FiveHundred.{Deck, Card}

  @type t :: [Card.t()]

  @spec new_shuffled() :: Deck.t()
  @doc """
  new_shuffled/0: returns a new shuffled four-handed deck
  """
  def new_shuffled() do
    new_deck()
    |> Enum.filter(&four_handed_filter/1)
    |> Enum.shuffle()
  end

  @spec new_deck() :: Deck.t()
  # new_deck/0: creates a new 53 card deck, including the joker
  defp new_deck() do
    for suit <- Card.traditional_suits(), rank <- Card.ranks() do
      %Card{rank: rank, suit: suit}
    end
    |> Enum.concat([Card.joker()])
  end

  @spec four_handed_filter(Card.t()) :: boolean
  # four_handed_filter/1: given a card, returns a boolean indicating
  # whether it should be included for a four-handed deck.
  # Filters red fours down exclusive.
  defp four_handed_filter(%Card{suit: _, rank: rank})
       when rank <= 3,
       do: false

  defp four_handed_filter(%Card{suit: suit, rank: rank})
       when rank == 4 and suit == :spades,
       do: false

  defp four_handed_filter(%Card{suit: suit, rank: rank})
       when rank == 4 and suit == :clubs,
       do: false

  defp four_handed_filter(%Card{}), do: true
end
