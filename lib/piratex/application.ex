defmodule Piratex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PiratexWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:piratex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Piratex.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Piratex.Finch},
      # Start a worker by calling: Piratex.Worker.start_link(arg)
      # {Piratex.Worker, arg},
      {Registry, keys: :unique, name: Piratex.Game.Registry},
      # # Dictionary manages an ETS table of words. It is global and never updated.
      {Piratex.Dictionary, []},
      {Piratex.DynamicSupervisor, name: Piratex.DynamicSupervisor},
      # Start to serve requests, typically the last entry
      PiratexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Piratex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PiratexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
