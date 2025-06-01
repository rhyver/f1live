defmodule F1liveWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "f1:*", F1liveWeb.F1Channel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end 