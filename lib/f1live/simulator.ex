defmodule F1live.Simulator do
  use GenServer
  require Logger

  @update_interval 1000  # Update every second
  @drivers [
    %{number: "1", tla: "VER", full_name: "Max VERSTAPPEN", team: "Red Bull Racing"},
    %{number: "11", tla: "PER", full_name: "Sergio PEREZ", team: "Red Bull Racing"},
    %{number: "44", tla: "HAM", full_name: "Lewis HAMILTON", team: "Mercedes"},
    %{number: "63", tla: "RUS", full_name: "George RUSSELL", team: "Mercedes"},
    %{number: "16", tla: "LEC", full_name: "Charles LECLERC", team: "Ferrari"},
    %{number: "55", tla: "SAI", full_name: "Carlos SAINZ", team: "Ferrari"},
    %{number: "4", tla: "NOR", full_name: "Lando NORRIS", team: "McLaren"},
    %{number: "81", tla: "PIA", full_name: "Oscar PIASTRI", team: "McLaren"},
    %{number: "14", tla: "ALO", full_name: "Fernando ALONSO", team: "Aston Martin"},
    %{number: "18", tla: "STR", full_name: "Lance STROLL", team: "Aston Martin"},
    %{number: "10", tla: "GAS", full_name: "Pierre GASLY", team: "Alpine"},
    %{number: "31", tla: "OCO", full_name: "Esteban OCON", team: "Alpine"},
    %{number: "23", tla: "ALB", full_name: "Alexander ALBON", team: "Williams"},
    %{number: "2", tla: "SAR", full_name: "Logan SARGEANT", team: "Williams"},
    %{number: "77", tla: "BOT", full_name: "Valtteri BOTTAS", team: "Alfa Romeo"},
    %{number: "24", tla: "ZHO", full_name: "Guanyu ZHOU", team: "Alfa Romeo"},
    %{number: "20", tla: "MAG", full_name: "Kevin MAGNUSSEN", team: "Haas"},
    %{number: "27", tla: "HUL", full_name: "Nico HULKENBERG", team: "Haas"},
    %{number: "3", tla: "RIC", full_name: "Daniel RICCIARDO", team: "AlphaTauri"},
    %{number: "22", tla: "TSU", full_name: "Yuki TSUNODA", team: "AlphaTauri"}
  ]

  @tire_compounds ["SOFT", "MEDIUM", "HARD", "INTERMEDIATE", "WET"]
  @track_statuses [
    %{status: "1", message: "Track Clear", color: "green"},
    %{status: "2", message: "Yellow Flag", color: "yellow"},
    %{status: "4", message: "Red Flag", color: "red"},
    %{status: "6", message: "Virtual Safety Car", color: "blue"},
    %{status: "7", message: "Safety Car", color: "orange"}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting F1 Data Simulator")

    # Initialize state
    state = %{
      drivers: initialize_drivers(),
      lap_number: 1,
      session_time: 0,
      weather: initialize_weather(),
      track_status: %{status: "1", message: "Track Clear"},
      race_control_messages: [],
      session_info: initialize_session_info()
    }

    # Start simulation and broadcast initial data after a short delay
    schedule_update()
    Process.send_after(self(), :broadcast_initial, 1000)

    {:ok, state}
  end

  def handle_info(:broadcast_initial, state) do
    broadcast_initial_data(state)
    {:noreply, state}
  end

  def handle_info(:update, state) do
    # Update simulation data
    new_state = update_simulation_data(state)

    # Broadcast updates
    broadcast_timing_data(new_state)

    # Occasionally update other data
    if rem(new_state.session_time, 10) == 0 do
      broadcast_weather_data(new_state)
      broadcast_track_status(new_state)
    end

    if rem(new_state.session_time, 30) == 0 do
      broadcast_race_control_message(new_state)
    end

    # Schedule next update
    schedule_update()

    {:noreply, new_state}
  end

  defp schedule_update() do
    Process.send_after(self(), :update, @update_interval)
  end

  defp initialize_drivers() do
    @drivers
    |> Enum.with_index(1)
    |> Enum.map(fn {driver, position} ->
      base_lap_time = 75000 + :rand.uniform(5000)  # 75-80 seconds

      %{
        number: driver.number,
        position: position,
        tla: driver.tla,
        full_name: driver.full_name,
        team: driver.team,
        gap_to_leader: if(position == 1, do: "", else: "+#{(position - 1) * 0.5 + :rand.uniform(100) / 100}s"),
        interval: if(position == 1, do: "", else: "+#{0.2 + :rand.uniform(80) / 100}s"),
        last_lap_time: format_lap_time(base_lap_time + :rand.uniform(2000)),
        best_lap_time: format_lap_time(base_lap_time - :rand.uniform(1000)),
        sector_1: format_sector_time(24000 + :rand.uniform(2000)),
        sector_2: format_sector_time(26000 + :rand.uniform(2000)),
        sector_3: format_sector_time(25000 + :rand.uniform(2000)),
        tire_compound: Enum.random(@tire_compounds),
        tire_age: :rand.uniform(30),
        laps_completed: :rand.uniform(3),
        speed: 280 + :rand.uniform(40),
        personal_fastest: false,
        overall_fastest: position == 1
      }
    end)
  end

  defp initialize_weather() do
    %{
      track_temp: 35 + :rand.uniform(20),
      air_temp: 22 + :rand.uniform(15),
      wind_speed: :rand.uniform(25),
      humidity: 40 + :rand.uniform(40),
      pressure: 1000 + :rand.uniform(50)
    }
  end

  defp initialize_session_info() do
    %{
      name: "Race",
      type: "Race",
      meeting: %{name: "Simulator Grand Prix"},
      remaining_time: "01:45:32",
      session_status: "Started",
      track_length: 5.891,
      total_laps: 70
    }
  end

  defp update_simulation_data(state) do
    # Update lap times with some randomness
    updated_drivers = Enum.map(state.drivers, fn driver ->
      # Simulate lap time variations
      base_time = 75000 + :rand.uniform(5000)
      variation = :rand.uniform(3000) - 1500
      new_lap_time = base_time + variation

      # Occasionally mark as personal fastest
      personal_fastest = :rand.uniform(20) == 1

      # Update tire age
      new_tire_age = if rem(state.session_time, 20) == 0 and :rand.uniform(10) == 1 do
        0  # Pit stop
      else
        driver.tire_age + 1
      end

      %{driver |
        last_lap_time: format_lap_time(new_lap_time),
        sector_1: format_sector_time(24000 + :rand.uniform(2000)),
        sector_2: format_sector_time(26000 + :rand.uniform(2000)),
        sector_3: format_sector_time(25000 + :rand.uniform(2000)),
        tire_age: new_tire_age,
        tire_compound: if(new_tire_age == 0, do: Enum.random(@tire_compounds), else: driver.tire_compound),
        speed: 280 + :rand.uniform(40),
        personal_fastest: personal_fastest,
        laps_completed: driver.laps_completed + if(rem(state.session_time, 80) == 0, do: 1, else: 0)
      }
    end)

    # Occasionally shuffle positions slightly
    shuffled_drivers = if rem(state.session_time, 15) == 0 do
      shuffle_positions(updated_drivers)
    else
      updated_drivers
    end

    # Update weather slightly
    updated_weather = %{state.weather |
      track_temp: max(20, min(60, state.weather.track_temp + (:rand.uniform(30) - 15) / 10)),
      air_temp: max(15, min(40, state.weather.air_temp + (:rand.uniform(20) - 10) / 10)),
      wind_speed: max(0, min(50, state.weather.wind_speed + (:rand.uniform(40) - 20) / 10))
    }

    %{state |
      drivers: shuffled_drivers,
      session_time: state.session_time + 1,
      weather: updated_weather,
      lap_number: state.lap_number + if(rem(state.session_time, 80) == 0, do: 1, else: 0)
    }
  end

  defp shuffle_positions(drivers) do
    # Occasionally swap adjacent positions
    if :rand.uniform(3) == 1 and length(drivers) > 1 do
      index = :rand.uniform(length(drivers) - 1) - 1
      driver1 = Enum.at(drivers, index)
      driver2 = Enum.at(drivers, index + 1)

      updated_driver1 = %{driver1 | position: driver2.position}
      updated_driver2 = %{driver2 | position: driver1.position}

      drivers
      |> List.replace_at(index, updated_driver2)
      |> List.replace_at(index + 1, updated_driver1)
    else
      drivers
    end
  end

  defp broadcast_initial_data(state) do
    Logger.info("F1 simulator initialized with 20 drivers")

    # Broadcast data source info
    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:data_source, "simulator"})

    # Broadcast driver list
    driver_list = state.drivers
    |> Enum.map(fn driver ->
      {driver.number, %{
        "Tla" => driver.tla,
        "FullName" => driver.full_name,
        "TeamName" => driver.team
      }}
    end)
    |> Enum.into(%{})

    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "DriverList", driver_list})

    # Broadcast session info
    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "SessionInfo", state.session_info})

    # Broadcast initial timing data
    broadcast_timing_data(state)
    broadcast_weather_data(state)
    broadcast_track_status(state)
  end

  defp broadcast_timing_data(state) do
    lines = state.drivers
    |> Enum.map(fn driver ->
      {driver.number, %{
        "Position" => driver.position,
        "GapToLeader" => driver.gap_to_leader,
        "IntervalToPositionAhead" => %{"Value" => driver.interval},
        "LastLapTime" => %{
          "Value" => driver.last_lap_time,
          "PersonalFastest" => driver.personal_fastest
        },
        "BestLapTime" => %{
          "Value" => driver.best_lap_time,
          "OverallFastest" => driver.overall_fastest
        },
        "Sectors" => [
          %{"Value" => driver.sector_1, "PersonalFastest" => false, "OverallFastest" => false},
          %{"Value" => driver.sector_2, "PersonalFastest" => false, "OverallFastest" => false},
          %{"Value" => driver.sector_3, "PersonalFastest" => false, "OverallFastest" => false}
        ],
        "Tyre" => %{
          "Compound" => driver.tire_compound,
          "TotalLaps" => driver.tire_age
        },
        "Speed" => driver.speed
      }}
    end)
    |> Enum.into(%{})

    timing_data = %{"Lines" => lines}
    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "TimingData", timing_data})
  end

  defp broadcast_weather_data(state) do
    weather_data = %{
      "TrackTemp" => "#{state.weather.track_temp}",
      "AirTemp" => "#{state.weather.air_temp}",
      "WindSpeed" => "#{state.weather.wind_speed}",
      "Humidity" => "#{state.weather.humidity}",
      "Pressure" => "#{state.weather.pressure}"
    }

    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "WeatherData", weather_data})
  end

  defp broadcast_track_status(_state) do
    # Occasionally change track status
    new_status = if :rand.uniform(50) == 1 do
      Enum.random(@track_statuses)
    else
      %{status: "1", message: "Track Clear", color: "green"}
    end

    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "TrackStatus", %{"Status" => new_status.status, "Message" => new_status.message}})
  end

  defp broadcast_race_control_message(_state) do
    messages = [
      "DRS ENABLED",
      "TRACK CLEAR",
      "CAR #{Enum.random(1..20)} - 5 SEC TIME PENALTY - TRACK LIMITS",
      "SAFETY CAR IN THIS LAP",
      "PIT LANE OPEN",
      "VIRTUAL SAFETY CAR ENDING",
      "WEATHER UPDATE - LIGHT RAIN EXPECTED"
    ]

    message = %{
      "Message" => Enum.random(messages),
      "TimeStamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "Category" => "Other"
    }

    Phoenix.PubSub.broadcast(F1live.PubSub, "f1:live", {:f1_data, "RaceControlMessages", %{"Messages" => [message]}})
  end

  defp format_lap_time(milliseconds) do
    minutes = div(milliseconds, 60000)
    seconds = div(rem(milliseconds, 60000), 1000)
    ms = rem(milliseconds, 1000)

    "#{minutes}:#{String.pad_leading("#{seconds}", 2, "0")}.#{String.pad_leading("#{ms}", 3, "0")}"
  end

  defp format_sector_time(milliseconds) do
    seconds = div(milliseconds, 1000)
    ms = rem(milliseconds, 1000)

    "#{seconds}.#{String.pad_leading("#{ms}", 3, "0")}"
  end
end
