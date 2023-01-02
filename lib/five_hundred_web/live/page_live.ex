defmodule FiveHundredWeb.PageLive do
  use FiveHundredWeb, :live_view
  import Phoenix.HTML.Form
  alias FiveHundred.{Game, Player, GameServer}
  alias FiveHundredWeb.GameStarter

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket 
    |> assign(:changeset, GameStarter.insert_changeset(%{})) }
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
    IO.inspect(params)
    with {:ok, starter} <- GameStarter.create(params),
         player <- %Player{name: starter.player_name},
         {:ok, game_code} <- GameStarter.get_game_code(starter),
         {:ok, _} <- GameServer.start_or_join(game_code, player) do
      socket =
      assign(socket, :player_name, starter.player_name)
      |>
      push_redirect(to: Routes.play_path(socket, :index, game: game_code, player: player.name))

      {:noreply, socket}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp new_game?(changeset) do
    Ecto.Changeset.get_field(changeset, :game_code) != nil
  end
end
