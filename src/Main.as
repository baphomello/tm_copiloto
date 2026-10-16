[Setting name="Record runs" description="Automatically record telemetry of every run to the plugin storage folder."]
bool S_Record = true;

[Setting name="Show status window"]
bool S_ShowWindow = true;

[Setting name="Sample rate (Hz)" min=1 max=100 description="Target frames recorded per second of race time. The real rate cannot exceed your frame rate."]
int S_SampleRateHz = 25;

void Main()
{
	print("Loaded version " + Meta::ExecutingPlugin().Version);
}

void Update(float dt)
{
	UpdateRecorder();
}

// Close the current file cleanly when the plugin is disabled, reloaded or unloaded.
void OnDisabled()
{
	EndRun("stopped");
}

void OnDestroyed()
{
	EndRun("stopped");
}

void RenderMenu()
{
	if (UI::BeginMenu("tm_copiloto")) {
		if (UI::MenuItem("Record runs", "", S_Record)) S_Record = !S_Record;
		if (UI::MenuItem("Show status window", "", S_ShowWindow)) S_ShowWindow = !S_ShowWindow;
		UI::EndMenu();
	}
}

void Render()
{
	if (!S_ShowWindow) return;
	if (UI::Begin("tm_copiloto", S_ShowWindow, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
		UI::Text(S_Record ? "Recording: enabled" : "Recording: disabled");
		UI::Text(g_run is null ? "Waiting for a run" : "Recording run: " + g_run.frames + " frames");
		if (g_lastFile != "") UI::Text("Last file: " + g_lastFile);
		if (UI::CollapsingHeader("Live values")) RenderLiveValues();
	}
	UI::End();
}

// Debug view used to check in-game that every recorded field reads correctly.
void RenderLiveValues()
{
	auto map = GetApp().RootMap;
	if (map !is null) UI::Text("Map: " + Text::StripFormatCodes(string(map.MapName)) + " (" + map.EdChallengeId + ")");
	UI::Text("In editor: " + (GetApp().Editor !is null));

	auto player = GetLocalPlayer();
	if (player is null) {
		UI::Text("Local player: not driving");
		return;
	}

	auto race = MLFeed::GetRaceData_V4();
	auto feed = race.LocalPlayer;
	if (feed is null) {
		UI::Text("MLFeed: no local player");
	} else {
		UI::Text("MLFeed race time: " + feed.CurrentRaceTime + " ms (start " + feed.StartTime + ", spawn " + tostring(feed.SpawnStatus) + ")");
		UI::Text("MLFeed CPs: " + feed.CpCount + " / " + race.CPsToFinish + ", last " + feed.LastCpTime + " ms, respawns " + feed.NbRespawnsRequested);
	}

	auto native = cast<CSmScriptPlayer>(player.ScriptAPI);
	if (native !is null) {
		uint n = native.RaceWaypointTimes.Length;
		uint last = 0;
		if (n > 0) last = native.RaceWaypointTimes[n - 1];
		UI::Text("Native race time: " + native.CurrentRaceTime + " ms (start " + native.StartTime + ")");
		UI::Text("Native waypoints: " + n + ", last " + last + " ms, respawns " + native.CurrentRaceRespawns);
	}

	auto s = GetCarState(player);
	if (s is null) {
		UI::Text("Car state: unavailable");
		return;
	}
	UI::Separator();
	UI::Text("Vehicle: " + tostring(VehicleState::GetVehicleType(s)));
	UI::Text("Position: " + s.Position.ToString());
	UI::Text("Velocity: " + s.WorldVel.ToString());
	UI::Text("Front speed: " + Text::Format("%.2f", s.FrontSpeed) + " m/s (" + Text::Format("%.0f", s.FrontSpeed * 3.6f) + " km/h)");
	UI::Text("Gear: " + s.CurGear + ", RPM: " + Text::Format("%.0f", VehicleState::GetRPM(s)));
	UI::Text("Steer: " + Text::Format("%.2f", s.InputSteer) + ", gas: " + Text::Format("%.2f", s.InputGasPedal) + ", brake: " + Text::Format("%.2f", s.InputBrakePedal));
	UI::Text("Ground contact: " + s.IsGroundContact);
	UI::Text("Surface FL: " + tostring(s.FLGroundContactMaterial) + ", FR: " + tostring(s.FRGroundContactMaterial));
	UI::Text("Surface RL: " + tostring(s.RLGroundContactMaterial) + ", RR: " + tostring(s.RRGroundContactMaterial));
}
