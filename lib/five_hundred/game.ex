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

  @spec bid(t(), PlayerBid.t()) :: {:ok, %Game{}} | {:error, :last_round_winner_must_bid_first | :not_bidding | :bid_not_high_enough | :cannot_bid}
  def bid(%Game{winning_bid: nil, last_round_winner: last_round_winner}, %PlayerBid{player_index: player_index})
    when last_round_winner != player_index,
    do: {:error, :last_round_winner_must_bid_first}

  def bid(%Game{} = game, %PlayerBid{player_index: player_index} = playerBid) do
    {:ok, game}
    |> ensure_bidding
    |> ensure_turn(player_index)
    |> ensure_can_bid(player_index)
    |> ensure_bid_is_higher(playerBid)
    |> set_winning_bid(playerBid)
    |> bid_advance
    |> advance_turn
  end

  @spec pass(t(), integer()) :: {:ok, t()} | {:error, :not_your_turn | :not_bidding}
  def pass(%Game{} = game, player_index) do
    {:ok, game}
    |> ensure_bidding
    |> ensure_turn(player_index)
    |> exclude_from_bidding(player_index)
    |> bid_advance
    |> advance_turn
  end

  @spec bid_advance({:ok | :error, t() | String.t()}) :: {:ok, t()} | {:error, :not_bidding}
  def bid_advance({:error, message}), do: {:error, message}
  def bid_advance({:ok, %Game{bid_exclusion: bid_exclusion, players: players} = game})
    when length(bid_exclusion) == (length(players) - 1),
    do: {:ok, %Game{game | state: :playing}}
  def bid_advance({:ok, %Game{}} = result), do: result

  @spec advance_turn({:ok, t()}) :: {:ok, t()}
  def advance_turn({:error, _message} = result), do: result
  def advance_turn({:ok, %Game{players: players, turn: current_turn} = game}),
   do: {:ok, %Game{game | turn: rem(current_turn + 1, length(players))}}

  @spec ensure_bidding({:ok | :error, t()}) :: {:ok, t()} | {:error, :not_bidding}
  def ensure_bidding({:error, _message} = result), do: result
  def ensure_bidding({:ok, %Game{state: state}}) when state != :bidding,
    do: {:error, :not_bidding}
  def ensure_bidding(result), do: result

  @spec ensure_turn({:ok | :error, t()}, integer()) :: {:ok, t()} | {:error, :not_your_turn}
  def ensure_turn({:error, _message} = result), do: result
  def ensure_turn({:ok, %Game{turn: turn}}, player_index) when turn != player_index,
    do: {:error, :not_your_turn}
  def ensure_turn({:ok, %Game{} = game}, _player_index), do: {:ok, game}

  @spec ensure_bid_is_higher({:ok | :error, t()}) :: {:ok, t()} | {:error, :bid_not_high_enough}
  def ensure_bid_is_higher({:error, _message} = result), do: result
  def ensure_bid_is_higher({:ok, %Game{winning_bid: nil}} = result, %PlayerBid{}), do: result
  def ensure_bid_is_higher({:ok, %Game{winning_bid: %PlayerBid{bid: winning_bid}} = game}, %PlayerBid{bid: new_bid}) do
    case Bid.compare(new_bid, winning_bid) do
      :gt -> {:ok, %Game{game | winning_bid: new_bid}}
      _ -> {:error, :bid_not_high_enough}
    end
  end

  @spec ensure_can_bid({:ok | :error, t()}) :: {:ok, t()} | {:error, Atom.t()}
  def ensure_can_bid({:error, _message} = result), do: result
  def ensure_can_bid({:ok, %Game{bid_exclusion: bid_exclusion} = game}, player_index) do
    if Enum.member?(bid_exclusion, player_index) do
      {:error, :cannot_bid}
    else
      {:ok, game}
    end
  end

  @spec set_winning_bid({:ok | :error, t()}) :: {:ok, t()} | {:error, Atom.t()}
  def set_winning_bid({:error, _message} = result), do: result
  def set_winning_bid({:ok, %Game{} = game}, %PlayerBid{} = playerBid),
    do: {:ok, game |> Map.put(:winning_bid, playerBid)}

  @spec exclude_from_bidding({:ok | :error, t()}) :: {:ok, t()} | {:error, Atom.t()}
  def exclude_from_bidding({:error, _message} = result), do: result
  def exclude_from_bidding({:ok, %Game{bid_exclusion: bid_exclusion} = game}, player_index),
    do: {:ok, game |> Map.put(:bid_exclusion, [player_index | bid_exclusion])}

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
