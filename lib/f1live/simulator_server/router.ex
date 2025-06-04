defmodule F1live.SimulatorServer.Router do
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  get "/signalr/negotiate" do
    conn_id = Base.encode16(:crypto.strong_rand_bytes(8))
    token = Base.encode16(:crypto.strong_rand_bytes(16))
    body = Jason.encode!(%{"ConnectionId" => conn_id, "ConnectionToken" => token})
    send_resp(conn, 200, body)
  end

  match "/signalr/connect" do
    WebSockAdapter.upgrade(conn, F1live.SimulatorServer.Socket, %{}, [])
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
