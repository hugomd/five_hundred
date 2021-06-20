defmodule FiveHundred.DeckTest do
  use ExUnit.Case

  alias FiveHundred.{Deck, Card}

  test "excludes black fours and under" do
    deck =
      Deck.new_shuffled()
      |> Enum.filter(fn card -> card.rank <= 4 end)
      |> Enum.filter(fn card -> card.suit == :clubs || card.suit == :spades end)

    assert deck == []
  end
end
