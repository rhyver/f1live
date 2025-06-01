// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// F1 Live Timing Channel
let socket = new Socket("/socket", { params: {} });
socket.connect();

let channel = socket.channel("f1:live", {});

// State to store timing data
let timingData = {};
let driverList = {};
let sessionInfo = {};

channel
  .join()
  .receive("ok", (resp) => {
    console.log("Joined F1 channel successfully", resp);
    updateConnectionStatus(true);
  })
  .receive("error", (resp) => {
    console.log("Unable to join F1 channel", resp);
    updateConnectionStatus(false);
  });

// Handle F1 data updates
channel.on("f1_update", (payload) => {
  console.log("F1 Update:", payload);

  switch (payload.feed) {
    case "TimingData":
      updateTimingData(payload.data);
      break;
    case "DriverList":
      updateDriverList(payload.data);
      break;
    case "SessionInfo":
      updateSessionInfo(payload.data);
      break;
    case "WeatherData":
      updateWeatherData(payload.data);
      break;
    case "TrackStatus":
      updateTrackStatus(payload.data);
      break;
    case "RaceControlMessages":
      updateRaceControl(payload.data);
      break;
  }
});

// Handle data source updates
channel.on("data_source", (payload) => {
  console.log("Data source:", payload.source);
  updateDataSource(payload.source);
});

function updateConnectionStatus(connected) {
  const statusEl = document.getElementById("connection-status");
  if (statusEl) {
    statusEl.innerHTML = connected
      ? `
      <div class="w-2 h-2 bg-green-500 rounded-full mr-2 animate-pulse"></div>
      <span class="text-sm text-gray-400">Connected</span>
    `
      : `
      <div class="w-2 h-2 bg-red-500 rounded-full mr-2"></div>
      <span class="text-sm text-gray-400">Disconnected</span>
    `;
  }
}

function updateDataSource(source) {
  const sourceEl = document.getElementById("data-source");
  if (sourceEl) {
    const isLive = source === "live";
    sourceEl.innerHTML = `
      <div class="w-2 h-2 ${
        isLive ? "bg-green-500" : "bg-yellow-500"
      } rounded-full mr-2"></div>
      <span class="text-sm text-gray-400">${
        isLive ? "Live Data" : "Simulator"
      }</span>
    `;
  }
}

function updateTimingData(data) {
  // Update timing data state
  Object.assign(timingData, data.Lines || {});
  renderTimingTable();
}

function updateDriverList(data) {
  // Update driver list
  Object.assign(driverList, data);
}

function updateSessionInfo(data) {
  sessionInfo = data;
  const sessionInfoEl = document.getElementById("session-info");
  if (sessionInfoEl && data) {
    sessionInfoEl.innerHTML = `
      <h2 class="text-xl font-semibold mb-4">Session Information</h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <p class="text-gray-400 text-sm">Track</p>
          <p class="text-lg font-medium">${data.Meeting?.Name || "--"}</p>
        </div>
        <div>
          <p class="text-gray-400 text-sm">Session</p>
          <p class="text-lg font-medium">${data.Name || "--"}</p>
        </div>
        <div>
          <p class="text-gray-400 text-sm">Time Remaining</p>
          <p class="text-lg font-medium">${data.RemainingTime || "--:--:--"}</p>
        </div>
      </div>
    `;
  }
}

function updateWeatherData(data) {
  const weatherEl = document.getElementById("weather-data");
  if (weatherEl && data) {
    weatherEl.innerHTML = `
      <div class="flex justify-between">
        <span class="text-gray-400">Track Temp</span>
        <span>${data.TrackTemp || "--"}°C</span>
      </div>
      <div class="flex justify-between">
        <span class="text-gray-400">Air Temp</span>
        <span>${data.AirTemp || "--"}°C</span>
      </div>
      <div class="flex justify-between">
        <span class="text-gray-400">Wind Speed</span>
        <span>${data.WindSpeed || "--"} km/h</span>
      </div>
    `;
  }
}

function updateTrackStatus(data) {
  const statusEl = document.getElementById("track-status");
  if (statusEl && data) {
    let statusColor = "green";
    let statusText = "Track Clear";

    if (data.Status === "2") {
      statusColor = "yellow";
      statusText = "Yellow Flag";
    } else if (data.Status === "4") {
      statusColor = "red";
      statusText = "Red Flag";
    } else if (data.Status === "6") {
      statusColor = "blue";
      statusText = "Virtual Safety Car";
    } else if (data.Status === "7") {
      statusColor = "orange";
      statusText = "Safety Car";
    }

    statusEl.innerHTML = `
      <div class="flex items-center">
        <div class="w-4 h-4 bg-${statusColor}-500 rounded mr-2"></div>
        <span>${statusText}</span>
      </div>
    `;
  }
}

function updateRaceControl(data) {
  const rcEl = document.getElementById("race-control");
  if (rcEl && data && data.Messages) {
    const messages = data.Messages.slice(-3).reverse();
    rcEl.innerHTML =
      messages
        .map(
          (msg) => `
      <p class="text-gray-300">${msg.Message || ""}</p>
    `
        )
        .join("") || '<p class="text-gray-400">No messages</p>';
  }
}

function renderTimingTable() {
  const tbody = document.getElementById("timing-data");
  if (!tbody) return;

  // Convert timing data to array and sort by position
  const drivers = Object.entries(timingData)
    .map(([number, data]) => ({
      number,
      ...data,
      driverInfo: driverList[number] || {},
    }))
    .sort((a, b) => (a.Position || 999) - (b.Position || 999));

  if (drivers.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="11" class="px-4 py-8 text-center text-gray-500">
          Waiting for timing data...
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = drivers
    .map((driver) => {
      const lastLap = driver.LastLapTime?.Value || "--";
      const bestLap = driver.BestLapTime?.Value || "--";
      const gap = driver.GapToLeader || "";
      const interval = driver.IntervalToPositionAhead?.Value || "";

      return `
      <tr class="hover:bg-gray-700 transition-colors">
        <td class="px-4 py-3 font-medium">${driver.Position || "--"}</td>
        <td class="px-4 py-3">
          <div class="flex items-center">
            <span class="font-medium mr-2">${
              driver.driverInfo.Tla || driver.number
            }</span>
            <span class="text-gray-400 text-sm">${
              driver.driverInfo.FullName || ""
            }</span>
          </div>
        </td>
        <td class="px-4 py-3">${gap}</td>
        <td class="px-4 py-3">${interval}</td>
        <td class="px-4 py-3 ${
          driver.LastLapTime?.PersonalFastest ? "text-purple-400" : ""
        }">${lastLap}</td>
        <td class="px-4 py-3 ${
          driver.BestLapTime?.OverallFastest ? "text-purple-400" : ""
        }">${bestLap}</td>
        <td class="px-4 py-3 ${getSectorColor(driver.Sectors?.[0])}">${
        driver.Sectors?.[0]?.Value || "--"
      }</td>
        <td class="px-4 py-3 ${getSectorColor(driver.Sectors?.[1])}">${
        driver.Sectors?.[1]?.Value || "--"
      }</td>
        <td class="px-4 py-3 ${getSectorColor(driver.Sectors?.[2])}">${
        driver.Sectors?.[2]?.Value || "--"
      }</td>
        <td class="px-4 py-3">
          <span class="px-2 py-1 text-xs rounded ${getTyreColor(
            driver.Tyre?.Compound
          )}">${driver.Tyre?.Compound || "--"}</span>
        </td>
        <td class="px-4 py-3">${driver.Tyre?.TotalLaps || "--"}</td>
      </tr>
    `;
    })
    .join("");
}

function getSectorColor(sector) {
  if (!sector) return "";
  if (sector.OverallFastest) return "text-purple-400";
  if (sector.PersonalFastest) return "text-green-400";
  return "";
}

function getTyreColor(compound) {
  switch (compound) {
    case "SOFT":
      return "bg-red-600";
    case "MEDIUM":
      return "bg-yellow-600";
    case "HARD":
      return "bg-gray-600";
    case "INTERMEDIATE":
      return "bg-green-600";
    case "WET":
      return "bg-blue-600";
    default:
      return "bg-gray-700";
  }
}
