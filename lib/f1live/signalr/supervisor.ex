defmodule F1live.SignalR.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      %{
        id: F1live.SignalR.Client,
        start: {F1live.SignalR.Client, :start_link, [[name: F1live.SignalR.Client]]},
        restart: :transient
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end 