defmodule FiveHundred.Bid do
  @derive Jason.Encoder
  defstruct [:suit, :tricks]
  alias FiveHundred.{Bid, Card}

  @type t :: %Bid{
          suit: Card.suit(),
          tricks: integer
        }

  @spec compare(t(), t()) :: :lt | :gt | :eq
  def compare(a, b) do
    aVal = to_int(a)
    bVal = to_int(b)

    cond do
      aVal < bVal -> :lt
      aVal > bVal -> :gt
      aVal == bVal -> :eq
    end
  end

  @spec to_int(t()) :: integer
  @doc """
  Converts a bid to an integer for comparison.
  Multiplies tricks by 10 to offset addition of the suit.
  E.g. %Bid{suit: hearts, tricks: 6} = 3 + (6 * 10) = 63
  """
  def to_int(bid) do
    Card.suits()[bid.suit] + bid.tricks * 10
  end

  @spec sort_by_trick([t()]) :: [t()]
  def sort_by_trick(list), do: Enum.sort(list, &trick_comparator/2)

  @spec trick_comparator(t(), t()) :: boolean
  defp trick_comparator(ax, bx), do: ax.tricks >= bx.tricks

  @spec sort_by_suit([t()]) :: [t()]
  def sort_by_suit(list), do: Enum.sort(list, &suit_comparator/2)

  @spec suit_comparator(t(), t()) :: boolean
  defp suit_comparator(ax, bx), do: Card.suits()[ax.suit] >= Card.suits()[bx.suit]
end
