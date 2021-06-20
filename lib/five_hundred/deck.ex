defmodule FiveHundred.Deck do
  """
  @doc
  A four handed 500 deck
  """

  alias FiveHundred.{Deck, Card}

  def new_shuffled() do
    new_four_handed_deck() |> Enum.shuffle()
  end

  def new_four_handed_deck() do
    new_deck() |> Enum.filter(&four_handed_filter/1)
  end

  defp new_deck() do
    for suit <- Card.suits(), rank <- Card.ranks() do
      %Card{rank: rank, suit: suit}
    end
  end

  defp four_handed_filter(%Card{suit: suit, rank: rank} = card) when rank <= 3, do: false

  defp four_handed_filter(%Card{suit: suit, rank: rank} = card)
       when rank == 4 and suit == :spades,
       do: false

  defp four_handed_filter(%Card{suit: suit, rank: rank} = card) when rank == 4 and suit == :clubs,
    do: false

  defp four_handed_filter(%Card{}), do: true
end
