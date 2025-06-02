# F1 Live Timing Dashboard

A real-time Formula 1 telemetry and timing dashboard built with Elixir Phoenix, consuming the F1 live timing WebSocket similar to [f1-dash](https://github.com/slowlydev/f1-dash).

## Features

- 🏎️ Real-time F1 timing data
- 📊 Live leaderboard with driver positions, gaps, and intervals
- ⏱️ Lap times and sector times with color coding
- 🏁 Track status and race control messages
- 🌡️ Weather information
- 🛞 Tire compound and age tracking
- 🔄 Automatic reconnection on connection loss

## Prerequisites

- Elixir 1.14 or later
- Erlang/OTP 25 or later
- Node.js 14 or later (for assets)

## Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd f1live
```

2. Install dependencies:
```bash
mix deps.get
```

3. Install Node.js dependencies:
```bash
cd assets && npm install && cd ..
```

## Running the Application

To start your Phoenix server:

```bash
mix phx.server
```

Or inside IEx (Interactive Elixir):

```bash
iex -S mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Architecture

### Backend Components

- **SignalR Client** (`lib/f1live/signalr/client.ex`): Handles WebSocket connection to F1 live timing service
- **SignalR Supervisor** (`lib/f1live/signalr/supervisor.ex`): Manages the SignalR client lifecycle
- **Phoenix Channel** (`lib/f1live_web/channels/f1_channel.ex`): Broadcasts F1 data to connected web clients

### Data Feeds

The application subscribes to the following F1 data feeds:

- **TimingData**: Driver positions, lap times, sector times
- **SessionInfo**: Track information, session type, time remaining
- **DriverList**: Driver information (names, numbers, teams)
- **WeatherData**: Track and air temperature, wind speed
- **TrackStatus**: Yellow flags, red flags, safety car
- **RaceControlMessages**: Official race control messages
- **CarData**: Telemetry data
- **ExtrapolatedClock**: Session clock
- **TopThree**: Podium positions
- **TimingStats**: Statistical information
- **LapCount**: Current lap information

### Frontend

- Modern, responsive UI built with Tailwind CSS
- Real-time updates via Phoenix **LiveView**
- Color-coded timing information:
  - Purple: Fastest overall time
  - Green: Personal best time
- Tire compound indicators with appropriate colors

## Development

### Adding New Data Feeds

To add support for new data feeds:

1. Add the feed name to the subscription list in `lib/f1live/signalr/client.ex`
2. Handle the new feed in the LiveView (`lib/f1live_web/live/timing_live.ex`)
3. Update the UI to display the new data

### Customizing the UI

The UI is built using Tailwind CSS. You can customize the appearance by:

1. Modifying the templates in `lib/f1live_web/controllers/page_html/`
2. Updating the Tailwind configuration in `assets/tailwind.config.js`
3. Adding custom CSS in `assets/css/app.css`

## Troubleshooting

### Connection Issues

If the application fails to connect to the F1 timing service:

1. Check your internet connection
2. Verify that the F1 timing service is available
3. Check the application logs for error messages

### Missing Data

If some data is not displaying:

1. Ensure there's an active F1 session (practice, qualifying, or race)
2. Check the browser console for any errors
3. Verify that the data feed is being received in the Elixir logs

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This project is unofficial and is not associated in any way with the Formula 1 companies. F1, FORMULA ONE, FORMULA 1, FIA FORMULA ONE WORLD CHAMPIONSHIP, GRAND PRIX and related marks are trade marks of Formula One Licensing B.V.

## Acknowledgments

- Inspired by [f1-dash](https://github.com/slowlydev/f1-dash)
- Built with [Phoenix Framework](https://www.phoenixframework.org/)
- Real-time updates powered by Phoenix Channels
