defmodule F1liveWeb.F1Channel do
  use F1liveWeb, :channel
  require Logger

  @impl true
  def join("f1:live", _payload, socket) do
    # Subscribe to F1 data updates
    Phoenix.PubSub.subscribe(F1live.PubSub, "f1:live")

    Logger.info("Client joined F1 live channel")
    {:ok, socket}
  end

  @impl true
  def handle_info({:f1_data, feed_name, data}, socket) do
    # Broadcast F1 data to connected clients
    push(socket, "f1_update", %{
      feed: feed_name,
      data: data,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:data_source, source}, socket) do
    # Broadcast data source info to clients
    push(socket, "data_source", %{
      source: source,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
