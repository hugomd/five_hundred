defmodule FiveHundred.Game do
  @moduledoc """
  Models a game of 500

  TODO:
  - score
  - turn
  """
  alias FiveHundred.{Bid, Game, Player, PlayerBid}

  @derive Jason.Encoder
  defstruct [
    :winning_bid,
    :players,
    :turn,
    :code,
    :max_players,
    :last_round_winner,
    :bid_exclusion,
    state: :waiting_for_players
  ]

  @type code :: String.t()
  @type state :: :bidding | :playing | :waiting_for_players | :finished

  @type t :: %Game{
          code: nil | code(),
          players: [Player.t()],
          turn: nil | integer(),
          state: state,
          winning_bid: nil | PlayerBid.t(),
          max_players: integer(),
          bid_exclusion: [Player.t()],
          last_round_winner: nil | integer()
        }

  @spec new_game(Player.t()) :: t()
  def new_game(%Player{} = player, max_players \\ 4),
    do: %Game{
      code: code(),
      players: [player],
      max_players: max_players,
      last_round_winner: 0,
      turn: 0,
      bid_exclusion: [],
      winning_bid: nil
    }

  @spec join_game(t(), Player.t()) :: {:ok, t()} | {:error, :max_players}
  def join_game(%Game{players: players} = game, %Player{})
      when length(players) == game.max_players,
      do: {:error, :max_players}

  def join_game(%Game{players: players} = game, %Player{} = player) do
    {:ok, %Game{game | players: [player | players]}}
    |> ready_for_bidding?
  end

  @spec bid(t(), PlayerBid.t()) ::
          {:ok, %Game{}}
          | {:error,
             :last_round_winner_must_bid_first | :not_bidding | :bid_not_high_enough | :cannot_bid}

  def bid(%Game{} = game, %PlayerBid{player_index: player_index} = playerBid) do
    with {:ok, game} <- ensure_bidding(game),
         {:ok, game} <- ensure_last_winner_has_bid_first(game, playerBid),
         {:ok, game} <- ensure_turn(game, player_index),
         {:ok, game} <- ensure_can_bid(game, player_index),
         {:ok, game} <- ensure_bid_is_higher(game, playerBid),
         {:ok, game} <- set_winning_bid(game, playerBid),
         {:ok, game} <- bid_advance(game),
         {:ok, game} <- advance_turn(game),
         do: {:ok, game}
  end

  @spec ensure_last_winner_has_bid_first(t(), %PlayerBid{}) :: {:ok, t()} | {:error, :last_round_winner_bid_first}
  def ensure_last_winner_has_bid_first(%Game{winning_bid: nil, last_round_winner: last_round_winner}, %PlayerBid{
        player_index: player_index
      })
      when last_round_winner != player_index,
      do: {:error, :last_round_winner_must_bid_first}
  def ensure_last_winner_has_bid_first(%Game{} = game, %PlayerBid{}), do: {:ok, game}

  @spec pass(t(), integer()) :: {:ok, t()} | {:error, :not_your_turn | :not_bidding}
  def pass(%Game{} = game, player_index) do
    with {:ok, game} <- ensure_bidding(game),
         {:ok, game} <- ensure_turn(game, player_index),
         {:ok, game} <- ensure_can_bid(game, player_index),
         {:ok, game} <- exclude_from_bidding(game, player_index),
         {:ok, game} <- bid_advance(game),
         {:ok, game} <- advance_turn(game),
         do: {:ok, game}
  end

  @spec bid_advance(t()) :: {:ok, t()} | {:error, :not_bidding}
  def bid_advance(%Game{bid_exclusion: bid_exclusion, players: players} = game)
      when length(bid_exclusion) == length(players) - 1,
      do: {:ok, %Game{game | state: :playing}}

  def bid_advance(%Game{} = game), do: {:ok, game}

  @spec advance_turn(t()) :: {:ok, t()}
  def advance_turn(%Game{players: players, turn: current_turn} = game),
    do: {:ok, %Game{game | turn: rem(current_turn + 1, length(players))}}

  @spec ensure_bidding(t()) :: {:ok, t()} | {:error, :not_bidding}
  def ensure_bidding(%Game{state: state}) when state != :bidding,
    do: {:error, :not_bidding}

  def ensure_bidding(%Game{} = game), do: {:ok, game}

  @spec ensure_turn(t(), integer()) :: {:ok, t()} | {:error, :not_your_turn}
  def ensure_turn(%Game{turn: turn}, player_index) when turn != player_index,
    do: {:error, :not_your_turn}

  def ensure_turn(%Game{} = game, _player_index), do: {:ok, game}

  @spec ensure_bid_is_higher(t(), PlayerBid.t()) :: {:ok, t()} | {:error, :bid_not_high_enough}
  def ensure_bid_is_higher(%Game{winning_bid: nil} = game, %PlayerBid{}), do: {:ok, game}

  def ensure_bid_is_higher(
        %Game{winning_bid: %PlayerBid{bid: winning_bid}} = game,
        %PlayerBid{bid: new_bid} = playerBid
      ) do
    case Bid.compare(new_bid, winning_bid) do
      :gt -> set_winning_bid(game, playerBid)
      _ -> {:error, :bid_not_high_enough}
    end
  end

  @spec ensure_can_bid(t(), integer()) :: {:ok, t()} | {:error, Atom.t()}
  def ensure_can_bid(%Game{bid_exclusion: bid_exclusion} = game, player_index) do
    if Enum.member?(bid_exclusion, player_index) do
      {:error, :cannot_bid}
    else
      {:ok, game}
    end
  end

  @spec set_winning_bid(t(), PlayerBid.t()) :: {:ok, t()} | {:error, Atom.t()}
  def set_winning_bid(%Game{} = game, %PlayerBid{} = playerBid),
    do: {:ok, %Game{game | winning_bid: playerBid}}

  @spec exclude_from_bidding(t(), integer()) :: {:ok, t()} | {:error, Atom.t()}
  def exclude_from_bidding(%Game{bid_exclusion: bid_exclusion} = game, player_index),
    do: {:ok, %Game{game | bid_exclusion: [player_index | bid_exclusion]}}

  @spec ready_for_bidding?({:ok, t()}) :: {:ok, t()}
  def ready_for_bidding?({:ok, %Game{players: players, max_players: max_players} = game})
      when length(players) == max_players,
      do: {:ok, %Game{game | state: :bidding}}

  def ready_for_bidding?({:ok, %Game{} = game}), do: {:ok, game}

  @spec code(integer) :: String.t()
  def code(length \\ 5),
    do:
      :crypto.strong_rand_bytes(length)
      |> Base.url_encode64()
      |> binary_part(0, length)
      |> String.upcase()
end
