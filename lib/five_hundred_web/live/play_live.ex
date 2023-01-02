defmodule FiveHundredWeb.PlayLive do
  use FiveHundredWeb, :live_view
  require Logger
  alias Phoenix.PubSub
  alias FiveHundred.{Game, GameServer}

  @impl true
  def mount(%{"game" => game_code} = _params, session, socket) do
    # TODO: ensure session includes user_id, use a plug for this!
    if connected?(socket) do
      # Subscribe to game update notifications
      PubSub.subscribe(FiveHundred.PubSub, "game:#{game_code}")
      send(self(), :load_game_state)
    end

    {:ok,
     assign(socket,
       game_code: game_code,
       player_id: session["user_id"],
       player: nil,
       game: %Game{},
       server_found: GameServer.server_found?(game_code)
     )}
  end

  def mount(_params, _session, socket) do
    {:ok, push_redirect(socket, to: Routes.page_path(socket, :index))}
  end

  # TODO: handle bidding
  # TODO: handle playing

  @impl true
  def handle_info(:load_game_state, %{assigns: %{server_found: true}} = socket) do
    with game <- GameServer.get_current_game_state(socket.assigns.game_code),
         {:ok, player} <- Game.get_player(game, socket.assigns.player_id) do
      {:noreply, assign(socket, server_found: true, game: game, player: player)}
    else
      error ->
        Logger.error("Failed to load game server state. #{inspect(error)}")

        socket =
          socket
          |> push_redirect(to: Routes.page_path(socket, :index))

        {:noreply, assign(socket, :server_found, false)}
    end
  end

  @impl true
  def handle_info(:load_game_state, socket) do
    Logger.debug("Game server #{inspect(socket.assigns.game_code)} not found")
    # Schedule to check again
    Process.send_after(self(), :load_game_state, 500)
    {:noreply, assign(socket, :server_found, GameServer.server_found?(socket.assigns.game_code))}
  end

  @impl true
  def handle_info({:game_state, %Game{} = state} = _event, socket) do
    updated_socket =
      socket
      |> clear_flash()
      |> assign(:game, state)

    {:noreply, updated_socket}
  end
end
