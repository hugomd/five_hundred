defmodule FiveHundredWeb.Plug.AuthenticateUserSession do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil -> put_session(conn, :user_id, Ecto.UUID.generate())
      _ -> conn
    end
  end
end
