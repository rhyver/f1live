defmodule F1live.SignalR.Client do
  use WebSockex
  require Logger

  @signalr_base_url Application.compile_env(:f1live, :signalr_url, "https://livetiming.formula1.com")
  @signalr_ws_url (if String.starts_with?(@signalr_base_url, "https") do
                     String.replace_prefix(@signalr_base_url, "https", "wss") <> "/signalr"
                   else
                     String.replace_prefix(@signalr_base_url, "http", "ws") <> "/signalr"
                   end)
  @hub_name "Streaming"

  def start_link(opts \\ []) do
    case connect_with_retry() do
      {:ok, ws_url, initial_state} ->
        WebSockex.start_link(ws_url, __MODULE__, initial_state, opts)

      {:error, reason} ->
        Logger.error("Failed to establish F1 SignalR connection: #{inspect(reason)}")
        # Return :ignore to prevent supervisor from crashing
        :ignore
    end
  end

  defp connect_with_retry(attempts \\ 3) do
    case negotiate_connection() do
      {:ok, connection_data} ->
        ws_url = build_ws_url(connection_data)
        Logger.info("Connecting to F1 SignalR WebSocket: #{ws_url}")

        initial_state = %{
          hub: @hub_name,
          connection_id: connection_data["ConnectionId"],
          connection_token: connection_data["ConnectionToken"],
          subscriptions: [],
          message_id: 0
        }

        {:ok, ws_url, initial_state}

      {:error, _reason} when attempts > 1 ->
        Logger.warning("SignalR negotiation failed, retrying... (#{attempts - 1} attempts left)")
        Process.sleep(2000)
        connect_with_retry(attempts - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Negotiate connection with SignalR
  defp negotiate_connection() do
    negotiate_url = "#{@signalr_base_url}/signalr/negotiate?connectionData=%5B%7B%22name%22%3A%22Streaming%22%7D%5D&clientProtocol=1.5"

    headers = [
      {"User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"},
      {"Accept", "application/json"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Origin", "https://www.formula1.com"},
      {"Referer", "https://www.formula1.com/"}
    ]

    case HTTPoison.get(negotiate_url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Negotiation failed with status #{status_code}: #{body}")
        {:error, "Negotiation failed with status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Build WebSocket URL with connection parameters
  defp build_ws_url(connection_data) do
    connection_token = URI.encode_www_form(connection_data["ConnectionToken"])
    "#{@signalr_ws_url}/connect?transport=webSockets&connectionToken=#{connection_token}&connectionData=%5B%7B%22name%22%3A%22Streaming%22%7D%5D&tid=10"
  end

  # WebSocket connected callback
  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to F1 SignalR WebSocket")

    # Determine data source based on the URL
    data_source = if String.contains?(@signalr_base_url, "localhost") or String.contains?(@signalr_base_url, "127.0.0.1") do
      "simulator"
    else
      "live"
    end

    # Broadcast the correct data source
    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:data_source, data_source})

    # Subscribe to F1 feeds after a short delay
    Process.send_after(self(), :subscribe_to_feeds, 1000)
    {:ok, state}
  end

  # Handle subscription message
  @impl true
  def handle_info(:subscribe_to_feeds, state) do
    subscribe_to_feeds(state)
  end

  # Send frame helper
  def handle_info({:send_frame, frame}, state) do
    {:reply, frame, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # Subscribe to F1 timing feeds
  defp subscribe_to_feeds(state) do
    feeds = [
      "TimingData",
      "SessionInfo",
      "ExtrapolatedClock",
      "TopThree",
      "RcmSeries",
      "TimingStats",
      "TimingAppData",
      "WeatherData",
      "TrackStatus",
      "DriverList",
      "RaceControlMessages",
      "SessionData",
      "LapCount",
      "CarData"
    ]

    Enum.each(feeds, fn feed ->
      subscribe_message = %{
        "H" => @hub_name,
        "M" => "Subscribe",
        "A" => [[feed]],
        "I" => state.message_id
      }

      {:ok, json} = Jason.encode(subscribe_message)
      send(self(), {:send_frame, {:text, json}})
    end)

    {:ok, %{state | message_id: state.message_id + 1, subscriptions: feeds}}
  end

  # Handle incoming frames
  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, data} ->
        handle_signalr_message(data, state)

      {:error, _} ->
        # Handle non-JSON messages (like empty keep-alive)
        {:ok, state}
    end
  end

  # Handle different SignalR message types
  defp handle_signalr_message(%{"C" => _message_id} = _data, state) do
    # Initial welcome message
    Logger.debug("Received SignalR welcome message")
    {:ok, state}
  end

  defp handle_signalr_message(%{"M" => messages}, state) when is_list(messages) do
    # Handle data messages
    Enum.each(messages, fn message ->
      handle_data_message(message, state)
    end)

    {:ok, state}
  end

  defp handle_signalr_message(%{"R" => _result}, state) do
    # Handle method call results
    {:ok, state}
  end

  defp handle_signalr_message(_data, state) do
    # Handle other message types
    {:ok, state}
  end

  # Process F1 timing data messages
  defp handle_data_message(%{"H" => @hub_name, "M" => method, "A" => args}, _state) do
    case method do
      "feed" ->
        [feed_name, data] = args
        broadcast_feed_data(feed_name, data)

      _ ->
        Logger.debug("Received method: #{method}")
    end
  end

  defp handle_data_message(_message, _state), do: :ok

  # Broadcast feed data to Phoenix channels
  defp broadcast_feed_data(feed_name, data) do
    Logger.debug("Broadcasting #{feed_name} data")

    # Broadcast to Phoenix PubSub
    Phoenix.PubSub.broadcast(
      F1live.PubSub,
      "f1:live",
      {:f1_data, feed_name, data}
    )
  end

  # Handle disconnection
  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("Disconnected from F1 SignalR: #{inspect(disconnect_map)}")
    {:reconnect, state}
  end

  # Handle WebSocket control frames
  @impl true
  def handle_ping(ping_frame, state) do
    {:reply, {:pong, ping_frame}, state}
  end

  @impl true
  def handle_pong(_pong_frame, state) do
    {:ok, state}
  end
end
