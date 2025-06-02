defmodule F1liveWeb.TimingLive do
  use F1liveWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(F1live.PubSub, "f1:live")
    end

    {:ok,
     assign(socket,
       data_source: nil,
       timing_data: %{},
       driver_list: %{},
       session_info: %{},
       weather_data: %{},
       track_status: %{},
       race_control: [],
       connected: connected?(socket)
     )}
  end

  @impl true
  def handle_info({:data_source, source}, socket) do
    {:noreply, assign(socket, :data_source, source)}
  end

  def handle_info({:f1_data, "TimingData", data}, socket) do
    {:noreply, assign(socket, :timing_data, Map.get(data, "Lines", %{}))}
  end

  def handle_info({:f1_data, "DriverList", data}, socket) do
    {:noreply, assign(socket, :driver_list, data)}
  end

  def handle_info({:f1_data, "SessionInfo", data}, socket) do
    {:noreply, assign(socket, :session_info, data)}
  end

  def handle_info({:f1_data, "WeatherData", data}, socket) do
    {:noreply, assign(socket, :weather_data, data)}
  end

  def handle_info({:f1_data, "TrackStatus", data}, socket) do
    {:noreply, assign(socket, :track_status, data)}
  end

  def handle_info({:f1_data, "RaceControlMessages", data}, socket) do
    {:noreply, assign(socket, :race_control, Map.get(data, "Messages", []))}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp build_drivers(timing_data, driver_list) do
    timing_data
    |> Enum.map(fn {num, data} ->
      Map.merge(data, %{"number" => num, "driver" => Map.get(driver_list, num, %{})})
    end)
    |> Enum.sort_by(fn d -> Map.get(d, "Position", 999) end)
  end

  defp sector_class(sector) do
    cond do
      sector["OverallFastest"] -> "text-purple-400"
      sector["PersonalFastest"] -> "text-green-400"
      true -> ""
    end
  end

  defp tyre_class(compound) do
    case compound do
      "SOFT" -> "bg-red-600"
      "MEDIUM" -> "bg-yellow-600"
      "HARD" -> "bg-gray-600"
      "INTERMEDIATE" -> "bg-green-600"
      "WET" -> "bg-blue-600"
      _ -> "bg-gray-700"
    end
  end

  @impl true
  def render(assigns) do
    drivers = build_drivers(assigns.timing_data, assigns.driver_list)

    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <header class="bg-black border-b border-gray-800">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center">
              <h1 class="text-2xl font-bold text-red-500">F1 LIVE</h1>
              <span class="ml-4 text-sm text-gray-400">Real-time Timing</span>
            </div>
            <div class="flex items-center space-x-4">
              <div id="connection-status" class="flex items-center">
                <div class={"w-2 h-2 rounded-full mr-2 " <> if(@connected, do: "bg-green-500 animate-pulse", else: "bg-red-500")}></div>
                <span class="text-sm text-gray-400"><%= if @connected, do: "Connected", else: "Disconnected" %></span>
              </div>
              <div id="data-source" class="flex items-center">
                <div class={"w-2 h-2 rounded-full mr-2 " <> if(@data_source == "live", do: "bg-green-500", else: "bg-yellow-500")}></div>
                <span class="text-sm text-gray-400"><%= if @data_source == "live", do: "Live Data", else: "Simulator" %></span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div id="session-info" class="bg-gray-800 rounded-lg p-6 mb-8">
          <h2 class="text-xl font-semibold mb-4">Session Information</h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <p class="text-gray-400 text-sm">Track</p>
              <p class="text-lg font-medium"><%= @session_info["Meeting"] && @session_info["Meeting"]["Name"] || "--" %></p>
            </div>
            <div>
              <p class="text-gray-400 text-sm">Session</p>
              <p class="text-lg font-medium"><%= @session_info["Name"] || "--" %></p>
            </div>
            <div>
              <p class="text-gray-400 text-sm">Time Remaining</p>
              <p class="text-lg font-medium"><%= @session_info["RemainingTime"] || "--:--:--" %></p>
            </div>
          </div>
        </div>

        <div class="bg-gray-800 rounded-lg overflow-hidden mb-8">
          <div class="px-6 py-4 border-b border-gray-700">
            <h2 class="text-xl font-semibold">Live Timing</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-900">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Pos</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Driver</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Gap</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Interval</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Last Lap</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Best Lap</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">S1</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">S2</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">S3</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Tyre</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Laps</th>
                </tr>
              </thead>
              <tbody id="timing-data" class="divide-y divide-gray-700">
                <%= if Enum.empty?(drivers) do %>
                  <tr>
                    <td colspan="11" class="px-4 py-8 text-center text-gray-500">
                      Waiting for timing data...
                    </td>
                  </tr>
                <% else %>
                  <%= for driver <- drivers do %>
                    <tr class="hover:bg-gray-700 transition-colors">
                      <td class="px-4 py-3 font-medium"><%= driver["Position"] || "--" %></td>
                      <td class="px-4 py-3">
                        <div class="flex items-center">
                          <span class="font-medium mr-2"><%= driver["driver"]["Tla"] || driver["number"] %></span>
                          <span class="text-gray-400 text-sm"><%= driver["driver"]["FullName"] || "" %></span>
                        </div>
                      </td>
                      <td class="px-4 py-3"><%= driver["GapToLeader"] || "" %></td>
                      <td class="px-4 py-3"><%= driver["IntervalToPositionAhead"] && driver["IntervalToPositionAhead"]["Value"] || "" %></td>
                      <td class={"px-4 py-3 " <> if(driver["LastLapTime"] && driver["LastLapTime"]["PersonalFastest"], do: "text-purple-400", else: "")}><%= driver["LastLapTime"] && driver["LastLapTime"]["Value"] || "--" %></td>
                      <td class={"px-4 py-3 " <> if(driver["BestLapTime"] && driver["BestLapTime"]["OverallFastest"], do: "text-purple-400", else: "")}><%= driver["BestLapTime"] && driver["BestLapTime"]["Value"] || "--" %></td>
                      <td class={"px-4 py-3 " <> sector_class(Enum.at(driver["Sectors"],0))}><%= Enum.at(driver["Sectors"],0)["Value"] || "--" %></td>
                      <td class={"px-4 py-3 " <> sector_class(Enum.at(driver["Sectors"],1))}><%= Enum.at(driver["Sectors"],1)["Value"] || "--" %></td>
                      <td class={"px-4 py-3 " <> sector_class(Enum.at(driver["Sectors"],2))}><%= Enum.at(driver["Sectors"],2)["Value"] || "--" %></td>
                      <td class="px-4 py-3">
                        <span class={"px-2 py-1 text-xs rounded " <> tyre_class(driver["Tyre"] && driver["Tyre"]["Compound"])}><%= driver["Tyre"] && driver["Tyre"]["Compound"] || "--" %></span>
                      </td>
                      <td class="px-4 py-3"><%= driver["Tyre"] && driver["Tyre"]["TotalLaps"] || "--" %></td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold mb-4">Weather</h3>
            <div id="weather-data" class="space-y-2">
              <div class="flex justify-between">
                <span class="text-gray-400">Track Temp</span>
                <span><%= @weather_data["TrackTemp"] || "--" %>°C</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-400">Air Temp</span>
                <span><%= @weather_data["AirTemp"] || "--" %>°C</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-400">Wind Speed</span>
                <span><%= @weather_data["WindSpeed"] || "--" %> km/h</span>
              </div>
            </div>
          </div>

          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold mb-4">Track Status</h3>
            <div id="track-status" class="space-y-2">
              <div class="flex items-center">
                <div class={"w-4 h-4 rounded mr-2 bg-" <> track_color(@track_status["Status"])}></div>
                <span><%= @track_status["Message"] || "Track Clear" %></span>
              </div>
            </div>
          </div>

          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold mb-4">Race Control</h3>
            <div id="race-control" class="space-y-2 text-sm">
              <%= if Enum.empty?(@race_control) do %>
                <p class="text-gray-400">No messages</p>
              <% else %>
                <%= for msg <- Enum.take(Enum.reverse(@race_control), 3) do %>
                  <p class="text-gray-300"><%= msg["Message"] || "" %></p>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp track_color(status) do
    case status do
      "2" -> "yellow-500"
      "4" -> "red-500"
      "6" -> "blue-500"
      "7" -> "orange-500"
      _ -> "green-500"
    end
  end
end
