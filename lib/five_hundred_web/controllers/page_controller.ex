defmodule FiveHundredWeb.PageController do
  use FiveHundredWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
