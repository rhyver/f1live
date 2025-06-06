#!/usr/bin/env elixir

# Load the application without starting it
Application.load(:f1live)

# Start only the dependencies we need
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)
Application.ensure_all_started(:plug_cowboy)
Application.ensure_all_started(:websock_adapter)
Application.ensure_all_started(:phoenix_pubsub)

# Start the simulator server
{:ok, _} = F1live.SimulatorServer.Application.start(:normal, [])

# Keep the process alive
Process.sleep(:infinity)
