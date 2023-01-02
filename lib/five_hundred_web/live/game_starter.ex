defmodule FiveHundredWeb.GameStarter do
  use Ecto.Schema
  import Ecto.Changeset
  alias FiveHundred.{Game, GameServer}
  alias __MODULE__

  embedded_schema do
    field :player_name, :string
    field :game_code, :string
  end

  @type t :: %GameStarter{
          player_name: nil | String.t(),
          game_code: nil | String.t()
        }

  @doc false
  def insert_changeset(attrs) do
    %GameStarter{}
    |> cast(attrs, [:player_name, :game_code])
    |> validate_required([:player_name])
    |> validate_length(:player_name, max: 15)
    |> validate_length(:game_code, is: 5)
    |> uppercase_game_code()
    |> validate_game_code()
  end

  @doc false
  def uppercase_game_code(changeset) do
    case get_field(changeset, :game_code) do
      nil -> changeset
      value -> put_change(changeset, :game_code, String.upcase(value))
    end
  end

  @doc false
  def validate_game_code(changeset) do
    # Don't check for a running game server if there are errors on the game_code
    # field
    if changeset.errors[:game_code] do
      changeset
    else
      case get_field(changeset, :game_code) do
        nil ->
          changeset

        value ->
          if GameServer.server_found?(value) do
            changeset
          else
            add_error(changeset, :game_code, "not a running game")
          end
      end
    end
  end

  @doc """
  Get the game code to use for starting or joining the game.
  """
  @spec get_game_code(t()) :: {:ok, Game.game_code()} | {:error, String.t()}
  def get_game_code(%GameStarter{game_code: nil}), do: {:ok, Game.game_code()}
  def get_game_code(%GameStarter{game_code: code}), do: {:ok, code}

  @doc """
  Create the GameStart struct data from the changeset if valid.
  """
  @spec create(params :: map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    params
    |> insert_changeset()
    |> apply_action(:insert)
  end
end
