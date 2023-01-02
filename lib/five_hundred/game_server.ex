defmodule FiveHundred.GameServer do
  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias FiveHundred.{Game, Player, GameServer}

  # Client
  def child_spec(opts) do
    name = Keyword.get(opts, :name, GameServer)
    player = Keyword.fetch!(opts, :player)

    %{
      id: "#{GameServer}_#{name}",
      start: {GameServer, :start_link, [name, player]},
      # TODO: should this be longer?
      shutdown: 10_000,
      restart: :transient
    }
  end

  @doc """
  Start a GameServer with the specified game_code as the name.
  """
  def start_link(name, %Player{} = player) do
    case GenServer.start_link(GameServer, %{player: player, game_code: name},
           name: via_tuple(name)
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info(
          "Already started GameServer #{inspect(name)} at #{inspect(pid)}, returning :ignore"
        )

        :ignore
    end
  end

  @doc """
  Start a new game or join an existing game.
  """
  @spec start_or_join(Game.game_code(), Player.t()) ::
          {:ok, :started | :joined} | {:error, String.t()}
  def start_or_join(game_code, %Player{} = player) do
    case Horde.DynamicSupervisor.start_child(
           FiveHundred.DistributedSupervisor,
           {GameServer, [name: game_code, player: player]}
         ) do
      {:ok, _pid} ->
        Logger.info("Started game server #{inspect(game_code)}")
        {:ok, :started}

      :ignore ->
        Logger.info("Game server #{inspect(game_code)} already running. Joining")

        case join_game(game_code, player) do
          :ok -> {:ok, :joined}
          {:error, _reason} = error -> error
        end
    end
  end

  @doc """
  Join a running game server
  """
  @spec join_game(Game.game_code(), Player.t()) :: :ok | {:error, String.t()}
  def join_game(game_code, %Player{} = player) do
    GenServer.call(via_tuple(game_code), {:join_game, player})
  end

  @doc """
  Request and return the current game state.
  """
  @spec get_current_game_state(Game.game_code()) ::
          Game.t() | {:error, String.t()}
  def get_current_game_state(game_code) do
    GenServer.call(via_tuple(game_code), :current_state)
  end

  # Server
  @impl true
  def init(%{player: player, game_code: game_code}) do
    {:ok, Game.new_game(player, game_code)}
  end

  @impl true
  def handle_call({:join_game, %Player{} = player}, _from, %Game{} = game) do
    case Game.join_game(game, player) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, :ok, game}

      {:error, reason} = error ->
        Logger.error("Failed to join and start game. Error: #{inspect(reason)}")
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:current_state, _from, %Game{} = state) do
    {:reply, state, state}
  end

  @doc """
  Return the `:via` tuple for referencing and interacting with a specific
  GameServer.
  """
  def via_tuple(game_code), do: {:via, Horde.Registry, {FiveHundred.GameRegistry, game_code}}

  def broadcast_game_state(%Game{} = state) do
    PubSub.broadcast(FiveHundred.PubSub, "game:#{state.game_code}", {:game_state, state})
  end

  @doc """
  Lookup the GameServer and report if it is found. Returns a boolean.
  """
  @spec server_found?(Game.game_code()) :: boolean()
  def server_found?(game_code) do
    # Look up the game in the registry. Return if a match is found.
    case Horde.Registry.lookup(FiveHundred.GameRegistry, game_code) do
      [] -> false
      [{pid, _} | _] when is_pid(pid) -> true
    end
  end
end
