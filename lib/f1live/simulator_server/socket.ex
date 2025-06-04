defmodule F1live.SimulatorServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  @impl true
  def init(req, _state) do
    {:cowboy_websocket, req, %{subs: MapSet.new(), msg_id: 1}}
  end

  @impl true
  def websocket_init(state) do
    Phoenix.PubSub.subscribe(F1live.PubSub, "f1:live")
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"M" => "Subscribe", "A" => [[feed]]}} ->
        {:ok, %{state | subs: MapSet.put(state.subs, feed)}}
      _ ->
        {:ok, state}
    end
  end

  def websocket_handle(_frame, state), do: {:ok, state}

  @impl true
  def websocket_info({:f1_data, feed, data}, state) do
    if MapSet.member?(state.subs, feed) do
      msg = %{
        "C" => Integer.to_string(state.msg_id),
        "M" => [
          %{"H" => "Streaming", "M" => "feed", "A" => [feed, data]}
        ]
      }

      {:reply, {:text, Jason.encode!(msg)}, %{state | msg_id: state.msg_id + 1}}
    else
      {:ok, state}
    end
  end

  def websocket_info(_info, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok
end
