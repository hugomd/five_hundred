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
      shutdown: 10_000,
      restart: :transient
    }
  end

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

  def join_game(game_code, %Player{} = player) do
    GenServer.call(via_tuple(game_code), {:join_game, player})
  end

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

      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:bid, player_bid}, _from, game) do
    case Game.bid(game, player_bid) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, {:ok, game}, game}
      
      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:pass, player_index}, _from, game) do
    case Game.pass(game, player_index) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, {:ok, game}, game}
      
      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:play_card, player_index, card}, _from, game) do
    case Game.play_card(game, player_index, card) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, {:ok, game}, game}
      
      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:exchange_card, player_index, kitty_card, hand_card}, _from, game) do
    case Game.exchange_card(game, player_index, kitty_card, hand_card) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, {:ok, game}, game}
      
      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:complete_exchange, _from, game) do
    case Game.complete_exchange(game) do
      {:ok, game} ->
        broadcast_game_state(game)
        {:reply, {:ok, game}, game}
      
      {:error, _reason} = error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:current_state, _from, %Game{} = state) do
    {:reply, state, state}
  end

  def via_tuple(game_code), do: {:via, Horde.Registry, {FiveHundred.GameRegistry, game_code}}

  def broadcast_game_state(%Game{} = state) do
    PubSub.broadcast(FiveHundred.PubSub, "game:#{state.game_code}", {:game_state, state})
  end

  def server_found?(game_code) do
    case Horde.Registry.lookup(FiveHundred.GameRegistry, game_code) do
      [] -> false
      [{pid, _} | _] when is_pid(pid) -> true
    end
  end
end