defmodule FiveHundred.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Setup clustering
      {Cluster.Supervisor, [topologies, [name: FiveHundred.ClusterSupervisor]]},
      # Start the Ecto repository
      # FiveHundred.Repo,
      # Start the Telemetry supervisor
      FiveHundredWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: FiveHundred.PubSub},
      # Start the Endpoint (http/https)
      FiveHundredWeb.Endpoint,
      # Start a worker by calling: FiveHundred.Worker.start_link(arg)
      # {FiveHundred.Worker, arg}

      # Start the registry for tracking running games
      {Horde.Registry, [name: FiveHundred.GameRegistry, keys: :unique, members: :auto]},
      {Horde.DynamicSupervisor,
       [
         name: FiveHundred.DistributedSupervisor,
         shutdown: 1000,
         strategy: :one_for_one,
         members: :auto
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FiveHundred.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FiveHundredWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
