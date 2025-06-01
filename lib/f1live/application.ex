defmodule F1live.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      F1liveWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:f1live, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: F1live.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: F1live.Finch},
      # Start the F1 data simulator as part of the supervision tree
      F1live.Simulator,
      # Start to serve requests, typically the last entry
      F1liveWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: F1live.Supervisor]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    F1liveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
