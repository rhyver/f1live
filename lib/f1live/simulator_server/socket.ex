defmodule F1live.SimulatorServer.Socket do
  @behaviour WebSock
  require Logger

  @impl true
  def init(_state) do
    Phoenix.PubSub.subscribe(F1live.PubSub, "f1:live")
    {:ok, %{subs: MapSet.new(), msg_id: 1}}
  end

  @impl true
  def handle_in({text, :text}, state) do
    case Jason.decode(text) do
      {:ok, %{"M" => "Subscribe", "A" => [[feed]]}} ->
        {:ok, %{state | subs: MapSet.put(state.subs, feed)}}
      _ ->
        {:ok, state}
    end
  end

  def handle_in(_frame, state), do: {:ok, state}

  @impl true
  def handle_info({:f1_data, feed, data}, state) do
    if MapSet.member?(state.subs, feed) do
      msg = %{
        "C" => Integer.to_string(state.msg_id),
        "M" => [
          %{"H" => "Streaming", "M" => "feed", "A" => [feed, data]}
        ]
      }

      {:push, {:text, Jason.encode!(msg)}, %{state | msg_id: state.msg_id + 1}}
    else
      {:ok, state}
    end
  end

  def handle_info(_info, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok
end
