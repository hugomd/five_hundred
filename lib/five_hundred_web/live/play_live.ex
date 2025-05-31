defmodule FiveHundredWeb.PlayLive do
  use FiveHundredWeb, :live_view
  require Logger
  alias Phoenix.PubSub
  alias FiveHundred.{Game, GameServer, PlayerBid, Card, Bid}

  @impl true
  def mount(%{"game" => game_code} = _params, %{"user_id" => user_id} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(FiveHundred.PubSub, "game:#{game_code}")
      send(self(), :load_game_state)
    end

    {:ok,
     assign(socket,
       game_code: game_code,
       player_id: user_id,
       player: nil,
       game: %Game{},
       server_found: GameServer.server_found?(game_code),
       region: Application.get_env(:five_hundred, :region, "local"),
       error_message: nil,
       selected_kitty_card: nil,
       selected_hand_card: nil
     )}
  end

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/")}
  end

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
          |> push_navigate(to: ~p"/?#{[game: socket.assigns.game_code]}")

        {:noreply, assign(socket, :server_found, false)}
    end
  end

  @impl true
  def handle_info(:load_game_state, socket) do
    Logger.debug("Game server #{inspect(socket.assigns.game_code)} not found")
    Process.send_after(self(), :load_game_state, 500)
    {:noreply, assign(socket, :server_found, GameServer.server_found?(socket.assigns.game_code))}
  end

  @impl true
  def handle_info({:game_state, %Game{} = state} = _event, socket) do
    updated_socket =
      socket
      |> clear_flash()
      |> assign(:game, state)
      |> assign(:selected_kitty_card, nil)
      |> assign(:selected_hand_card, nil)

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("make_bid", %{"bid" => bid_params}, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    player_index = Enum.find_index(game.players, &(&1.id == player.id))
    
    # Find matching bid from available bids
    tricks = String.to_integer(bid_params["tricks"])
    suit = String.to_atom(bid_params["suit"])
    
    bid = Enum.find(Bid.bids(), fn b -> 
      b.tricks == tricks && b.suit == suit
    end)

    # Create the player bid
    player_bid = %PlayerBid{
      player_index: player_index,
      bid: bid
    }

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

  def handle_event("select_kitty_card", %{"suit" => suit, "rank" => rank}, socket) do
    card = %Card{
      suit: String.to_atom(suit),
      rank: String.to_integer(rank)
    }
    
    # Clear any existing hand card selection when selecting from kitty
    socket = assign(socket, :selected_hand_card, nil)
    
    socket = if socket.assigns.selected_kitty_card == card do
      # Clicking the same card deselects it
      assign(socket, :selected_kitty_card, nil)
    else
      assign(socket, :selected_kitty_card, card)
    end

    {:noreply, socket}
  end

  def handle_event("select_hand_card", %{"suit" => suit, "rank" => rank}, socket) do
    card = %Card{
      suit: String.to_atom(suit),
      rank: String.to_integer(rank)
    }
    
    # If we have both a kitty card and hand card selected, perform the exchange
    socket = if socket.assigns.selected_kitty_card != nil do
      exchange_cards(socket, socket.assigns.selected_kitty_card, card)
    else
      # Clear any existing hand card selection when selecting a new one
      assign(socket, :selected_hand_card, 
        if(socket.assigns.selected_hand_card == card, do: nil, else: card))
    end

    {:noreply, socket}
  end

  def handle_event("complete_exchange", _params, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    
    if game.state != :exchanging do
      {:noreply, assign(socket, error_message: "Can only complete exchange during the exchange phase")}
    else
      player_index = Enum.find_index(game.players, &(&1.id == player.id))
      
      if game.winning_bid.player_index != player_index do
        {:noreply, assign(socket, error_message: "Only the winning bidder can complete the exchange")}
      else
        if length(game.kitty) > 0 do
          {:noreply, assign(socket, error_message: "Must exchange all kitty cards before completing")}
        else
          case GenServer.call(via_tuple(game_code), :complete_exchange) do
            {:ok, _game} ->
              {:noreply, socket}
            
            {:error, reason} ->
              {:noreply, assign(socket, error_message: "Cannot complete exchange: #{reason}")}
          end
        end
      end
    end
  end

  def handle_event("play_card", %{"suit" => suit, "rank" => rank}, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    
    # Only allow playing cards on your turn
    if Enum.at(game.players, game.turn).id != player.id do
      {:noreply, assign(socket, error_message: "Not your turn")}
    else
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
  end

  def handle_event("exchange_selected", _params, socket) do
    if socket.assigns.selected_kitty_card && socket.assigns.selected_hand_card do
      socket = exchange_cards(socket, socket.assigns.selected_kitty_card, socket.assigns.selected_hand_card)
      {:noreply, socket}
    else
      {:noreply, assign(socket, error_message: "Please select both a kitty card and a hand card to exchange")}
    end
  end

  def handle_event("skip_exchange", _params, socket) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    
    if game.state != :exchanging do
      {:noreply, assign(socket, error_message: "Can only skip exchange during the exchange phase")}
    else
      player_index = Enum.find_index(game.players, &(&1.id == player.id))
      
      if game.winning_bid.player_index != player_index do
        {:noreply, assign(socket, error_message: "Only the winning bidder can skip exchange")}
      else
        # Skip exchange by moving directly to playing phase
        case GenServer.call(via_tuple(game_code), :complete_exchange) do
          {:ok, _game} ->
            {:noreply, socket}
          
          {:error, reason} ->
            {:noreply, assign(socket, error_message: "Cannot skip exchange: #{reason}")}
        end
      end
    end
  end

  def handle_event("ping", _, socket) do
    {:reply, %{}, socket}
  end

  defp exchange_cards(socket, kitty_card, hand_card) do
    %{game_code: game_code, player: player, game: game} = socket.assigns
    
    if game.state != :exchanging do
      assign(socket, error_message: "Can only exchange cards during the exchange phase")
    else
      player_index = Enum.find_index(game.players, &(&1.id == player.id))
      
      if game.winning_bid.player_index != player_index do
        assign(socket, error_message: "Only the winning bidder can exchange cards")
      else
        case GenServer.call(via_tuple(game_code), {:exchange_card, player_index, kitty_card, hand_card}) do
          {:ok, _game} ->
            socket
            |> assign(:selected_kitty_card, nil)
            |> assign(:selected_hand_card, nil)
            |> assign(:error_message, nil)  # Clear any existing error messages
          
          {:error, reason} ->
            assign(socket, error_message: "Exchange error: #{reason}")
        end
      end
    end
  end

  defp display_game_state(%{state: :waiting_for_players} = game) do
    "Waiting for players (#{length(game.players)}/#{game.max_players})"
  end

  defp display_game_state(%{state: :bidding} = game) do
    current_player = Enum.at(game.players, game.turn)
    player_number = game.turn + 1  # Add 1 to index for display
    excluded_players = Enum.map(game.bid_exclusion, &("Player #{&1 + 1}"))
    
    status = "Bidding phase - Player #{player_number}'s turn (#{current_player.name})"
    if length(excluded_players) > 0 do
      status <> "\nPassed players: #{Enum.join(excluded_players, ", ")}"
    else
      status
    end
  end

  defp display_game_state(%{state: :exchanging} = game) do
    winner_index = game.winning_bid.player_index
    winner = Enum.at(game.players, winner_index)
    "Player #{winner_index + 1} (#{winner.name}) is exchanging cards with the kitty"
  end

  defp display_game_state(%{state: :playing} = game) do
    current_player = Enum.at(game.players, game.turn)
    winner = Enum.at(game.players, game.winning_bid.player_index)
    "Playing phase - Player #{game.turn + 1}'s turn (#{current_player.name}) - " <>
      "Winning bid: #{game.winning_bid.bid.name} by Player #{game.winning_bid.player_index + 1} (#{winner.name})"
  end

  defp display_game_state(%{state: state}), do: "Game state: #{state}"

  defp display_card(%Card{rank: 15, suit: :joker}), do: "🃏"
  defp display_card(%Card{rank: rank, suit: suit}) do
    suit_symbol = case suit do
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
      :spades -> "♠"
      _ -> "?"
    end

    rank_symbol = case rank do
      11 -> "J"
      12 -> "Q"
      13 -> "K"
      14 -> "A"
      n -> to_string(n)
    end

    rank_symbol <> suit_symbol
  end

  defp card_color(%Card{suit: suit}) when suit in [:hearts, :diamonds], do: "text-red-600"
  defp card_color(_), do: "text-gray-900"

  # Order: Spades, Hearts, Diamonds, Clubs, then by rank
  defp sort_cards(cards) do
    suit_order = %{spades: 1, hearts: 2, diamonds: 3, clubs: 4, joker: 5}
    
    Enum.sort_by(cards, fn card -> 
      {Map.get(suit_order, card.suit), card.rank}
    end)
  end

  defp via_tuple(game_code), do: {:via, Horde.Registry, {FiveHundred.GameRegistry, game_code}}
end