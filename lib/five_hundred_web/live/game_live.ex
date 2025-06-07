defmodule FiveHundredWeb.GameLive do
  use FiveHundredWeb, :live_view
  require Logger

  alias FiveHundred.{Game, GameServer, Player, PlayerBid, Card, Bid}
  alias Phoenix.PubSub
  import FiveHundred.Game, only: [display_card: 1, last_completed_trick: 1, decision_to_string: 2]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       game_code: nil,
       game: nil,
       player: nil,
       error_message: nil
     )}
  end

  @impl true
  def handle_params(%{"code" => game_code}, _uri, socket) do
    if connected?(socket) do
      PubSub.subscribe(FiveHundred.PubSub, "game:#{game_code}")
    end

    {:noreply, assign(socket, game_code: game_code)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("create_game", _params, socket) do
    game_code = Game.game_code()
    player = create_player()

    case GameServer.start_or_join(game_code, player) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(player: player)
         |> push_patch(to: ~p"/game/#{game_code}")}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Failed to create game: #{reason}")}
    end
  end

  def handle_event("join_game", %{"game" => %{"code" => game_code}}, socket) do
    if GameServer.server_found?(game_code) do
      player = create_player()

      case GameServer.join_game(game_code, player) do
        :ok ->
          {:noreply,
           socket
           |> assign(player: player)
           |> push_patch(to: ~p"/game/#{game_code}")}

        {:error, reason} ->
          {:noreply, assign(socket, error_message: "Failed to join game: #{reason}")}
      end
    else
      {:noreply, assign(socket, error_message: "Game not found")}
    end
  end

  def handle_event("make_bid", %{"bid" => bid_params}, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns

    # Find player's index in the game
    player_index = Enum.find_index(game.players, &(&1.id == player.id))

    # Create the bid struct
    bid = %Bid{
      name: "#{bid_params["tricks"]} #{bid_params["suit"]}",
      suit: String.to_atom(bid_params["suit"]),
      tricks: String.to_integer(bid_params["tricks"]),
      points: calculate_bid_points(bid_params["tricks"], bid_params["suit"])
    }

    # Create the player bid
    player_bid = %PlayerBid{
      player_index: player_index,
      bid: bid
    }

    # Make the bid through the game server
    case GenServer.call(via_tuple(game_code), {:bid, player_bid}) do
      {:ok, _game} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Bid error: #{reason}")}
    end
  end

  def handle_event("pass", _params, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    player_index = Enum.find_index(game.players, &(&1.id == player.id))

    case GenServer.call(via_tuple(game_code), {:pass, player_index}) do
      {:ok, _game} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Pass error: #{reason}")}
    end
  end

  def handle_event("play_card", %{"suit" => suit, "rank" => rank}, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    player_index = Enum.find_index(game.players, &(&1.id == player.id))

    card = %Card{
      suit: String.to_atom(suit),
      rank: String.to_integer(rank)
    }

    case GenServer.call(via_tuple(game_code), {:play_card, player_index, card}) do
      {:ok, _game} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Cannot play card: #{reason}")}
    end
  end

  @impl true
  def handle_info({:game_state, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  defp create_player do
    %Player{
      id: Ecto.UUID.generate(),
      name: "Player #{:rand.uniform(1000)}"
    }
  end

  defp display_game_state(%{state: :waiting_for_players} = game) do
    "Waiting for players (#{length(game.players)}/#{game.max_players})"
  end

  defp display_game_state(%{state: :bidding} = game) do
    current_player = Enum.at(game.players, game.turn)
    excluded_players = Enum.map(game.bid_exclusion, &Enum.at(game.players, &1).name)

    status = "Bidding phase - #{current_player.name}'s turn"

    if length(excluded_players) > 0 do
      status <> "\nPassed players: #{Enum.join(excluded_players, ", ")}"
    else
      status
    end
  end

  defp display_game_state(%{state: :playing} = game) do
    "Playing phase - Winner: #{Enum.at(game.players, game.winning_bid.player_index).name} with #{game.winning_bid.bid.name}"
  end

  defp display_game_state(%{state: state}), do: "Game state: #{state}"

  defp card_color(%Card{suit: suit}) when suit in [:hearts, :diamonds], do: "text-red-600"
  defp card_color(_), do: "text-gray-900"

  defp calculate_bid_points(tricks, suit) do
    base_points =
      case suit do
        "spades" -> 40
        "clubs" -> 60
        "diamonds" -> 80
        "hearts" -> 100
        "no_trumps" -> 120
      end

    tricks = String.to_integer(tricks)
    base_points + (tricks - 6) * 100
  end

  defp via_tuple(game_code), do: {:via, Horde.Registry, {FiveHundred.GameRegistry, game_code}}
end

