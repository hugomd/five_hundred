defmodule FiveHundred.Repo do
  use Ecto.Repo,
    otp_app: :five_hundred,
    adapter: Ecto.Adapters.Postgres
end
