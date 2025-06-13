defmodule FiveHundredWeb.PageLive do
  use FiveHundredWeb, :live_view
  alias FiveHundred.{Game, Player, GameServer}
  alias FiveHundredWeb.GameStarter

  @impl true
  def mount(params, session, socket) do
    # TODO: ensure user ID exists in session

    {:ok,
     socket
     |> assign(
       changeset: GameStarter.insert_changeset(%{}),
       user_id: session["user_id"],
       region: Application.get_env(:five_hundred, :region, "local"),
       game_code: Map.get(params, "game", "")
     )}
  end

  @impl true
  def handle_event("validate", %{"game_starter" => params}, socket) do
    changeset =
      params
      |> GameStarter.insert_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"game_starter" => params}, socket) do
    with {:ok, starter} <- GameStarter.create(params),
         player <- %Player{id: socket.assigns.user_id, name: starter.player_name},
         {:ok, game_code} <- GameStarter.get_game_code(starter),
         {:ok, _} <- GameServer.start_or_join(game_code, player) do
      socket =
        assign(socket, :player_name, starter.player_name)
        |> push_navigate(to: ~p"/play?#{[game: game_code]}")

      {:noreply, socket}
    else
      {:error, reason} when is_binary(reason) ->
        {:noreply, put_flash(socket, :error, reason)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("ping", _, socket) do
    {:reply, %{}, socket}
  end

  defp new_game?(changeset) do
    Ecto.Changeset.get_field(changeset, :game_code) == nil
  end

  defp list_game_servers() do
    Horde.Registry.select(FiveHundred.GameRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> IO.inspect()
    |> Enum.map(&GameServer.get_current_game_state/1)
    |> Enum.map(fn %Game{state: state, game_code: game_code, players: players} ->
      {state, game_code, players |> Enum.map(fn p -> p.name end),
       node(Horde.Registry.whereis_name({FiveHundred.GameRegistry, game_code}))}
    end)
  end
end
