defmodule F1live.SimulatorServer.Application do
  @moduledoc """
  Application for running the F1 data simulator in a standalone server.
  It exposes the same SignalR API used by the live timing feed.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: F1live.PubSub},
      F1live.Simulator,
      {Plug.Cowboy, scheme: :http, plug: F1live.SimulatorServer.Router, options: [port: 4001]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
