const int SCHEMA_VERSION = 1;

class Run
{
	IO::File file;
	string path;
	int startTime;     // game time at which this run's race time is 0
	int nextSample = 0;
	int lastRaceTime = 0;
	uint frames = 0;
	int checkpoints = 0;  // waypoints already written, finish and lap lines included
	int respawns = 0;     // respawn lines already written
	string splits;        // comma-separated checkpoint times for the end line
}

Run@ g_run;
int g_handledStart = -1; // start time of the last recorded run, so a finished run is not recorded twice
string g_lastFile;

void UpdateRecorder()
{
	if (!S_Record) {
		EndRun("stopped");
		return;
	}
	auto api = GetApp().Network.PlaygroundClientScriptAPI;
	if (api is null || !IsRacing()) {
		EndRun("left");
		return;
	}

	// The player is briefly unavailable while the game respawns the car; keep the run open meanwhile.
	auto player = GetLocalPlayer();
	CSmScriptPlayer@ script = player is null ? null : cast<CSmScriptPlayer>(player.ScriptAPI);
	if (script is null) return;

	// Respawning at the start or pressing restart gives the player a new start time.
	if (g_run !is null && g_run.startTime != script.StartTime) EndRun("restart");

	int raceTime = api.GameTime - script.StartTime;
	if (g_run is null) {
		// Negative race time is the countdown before the car can move.
		if (raceTime < 0 || script.StartTime == g_handledStart) return;
		StartRun(player, script.StartTime);
	}
	if (raceTime >= g_run.nextSample) WriteFrame(player, raceTime);
	WriteRaceEvents();
}

// Checkpoints, respawns and the finish come from MLFeed, which reads them from the game's own race events.
void WriteRaceEvents()
{
	auto race = MLFeed::GetRaceData_V4();
	auto feed = race.LocalPlayer;
	// Right after a restart MLFeed may still describe the previous run for a frame or two.
	if (feed is null || int(feed.StartTime) != g_run.startTime) return;

	// RespawnTimes holds the moment of each respawn. LastRespawnRaceTime is not used: MLFeed adds a 1 s estimated penalty to it.
	auto respawnTimes = feed.RespawnTimes;
	while (g_run.respawns < int(respawnTimes.Length)) {
		g_run.file.WriteLine('{"type":"respawn","race_time":' + respawnTimes[g_run.respawns] + '}');
		g_run.respawns++;
	}

	auto times = feed.CpTimes; // index 0 is the start and always 0
	while (g_run.checkpoints < feed.CpCount) {
		g_run.checkpoints++;
		int t = times[g_run.checkpoints];
		g_run.file.WriteLine('{"type":"checkpoint","race_time":' + t + ',"index":' + g_run.checkpoints + '}');
		g_run.splits += (g_run.splits == "" ? "" : ",") + t;
		g_run.file.Flush();
	}

	if (race.CPsToFinish > 0 && g_run.checkpoints >= int(race.CPsToFinish)) EndRun("finish", times[g_run.checkpoints]);
}

void StartRun(CSmPlayer@ player, int startTime)
{
	auto app = GetApp();
	auto map = app.RootMap;
	string uid = map is null ? "" : map.EdChallengeId;
	if (uid == "") uid = "unknown-map";

	string dir = IO::FromStorageFolder("runs/" + Path::SanitizeFileName(uid));
	IO::CreateFolder(dir);

	@g_run = Run();
	g_run.startTime = startTime;
	// Milliseconds keep file names unique when restarting within the same second.
	g_run.path = dir + "/" + Time::FormatString("%Y%m%d-%H%M%S") + "-" + Text::Format("%03d", int(Time::MilliStamp % 1000)) + ".jsonl";
	g_run.file.Open(g_run.path, IO::FileMode::Write);

	auto mapInfo = Json::Object();
	mapInfo["uid"] = uid;
	mapInfo["name"] = map is null ? "" : Text::StripFormatCodes(string(map.MapName));
	mapInfo["author_login"] = map is null ? "" : map.AuthorLogin;
	mapInfo["author_name"] = map is null ? "" : Text::StripFormatCodes(string(map.AuthorNickName));

	auto car = GetCarState(player);
	auto header = Json::Object();
	header["type"] = "header";
	header["schema_version"] = SCHEMA_VERSION;
	header["plugin_version"] = Meta::ExecutingPlugin().Version;
	header["game_version"] = app.SystemPlatform.ExeVersion;
	header["recorded_at"] = Time::FormatStringUTC("%Y-%m-%dT%H:%M:%SZ");
	header["editor"] = app.Editor !is null;
	header["map"] = mapInfo;
	header["vehicle"] = car is null ? "" : tostring(VehicleState::GetVehicleType(car));
	header["sample_rate_hz"] = S_SampleRateHz;
	g_run.file.WriteLine(Json::Write(header));
}

void WriteFrame(CSmPlayer@ player, int raceTime)
{
	auto s = GetCarState(player);
	if (s is null) return;

	// Built by hand instead of with Json::Write to control float precision; every value is numeric or an enum name.
	g_run.file.WriteLine('{"type":"frame","race_time":' + raceTime
		+ ',"pos":' + Vec(s.Position) + ',"vel":' + Vec(s.WorldVel)
		+ ',"speed":' + Num(s.FrontSpeed) + ',"gear":' + s.CurGear + ',"rpm":' + Text::Format("%.0f", VehicleState::GetRPM(s))
		+ ',"steer":' + Num(s.InputSteer) + ',"gas":' + Num(s.InputGasPedal) + ',"brake":' + Num(s.InputBrakePedal)
		+ ',"ground":' + s.IsGroundContact
		+ ',"surface":["' + tostring(s.FLGroundContactMaterial) + '","' + tostring(s.FRGroundContactMaterial)
		+ '","' + tostring(s.RLGroundContactMaterial) + '","' + tostring(s.RRGroundContactMaterial) + '"]}');

	g_run.frames++;
	g_run.lastRaceTime = raceTime;
	// Align samples to a fixed race-time grid so frame-rate jitter does not drift the rate.
	int period = 1000 / S_SampleRateHz;
	g_run.nextSample = (raceTime / period + 1) * period;
}

void EndRun(const string &in reason, int raceTime = -1)
{
	if (g_run is null) return;
	if (raceTime < 0) raceTime = g_run.lastRaceTime;
	g_run.file.WriteLine('{"type":"end","reason":"' + reason + '","race_time":' + raceTime + ',"checkpoints":[' + g_run.splits + ']}');
	g_run.file.Close();
	print("Saved " + g_run.frames + " frames (" + reason + ") to " + g_run.path);
	g_handledStart = g_run.startTime;
	g_lastFile = g_run.path;
	@g_run = null;
}

string Num(float v)
{
	return Text::Format("%.3f", v);
}

string Vec(const vec3 &in v)
{
	return "[" + Num(v.x) + "," + Num(v.y) + "," + Num(v.z) + "]";
}

// True while a race is on screen: driving, or rolling past the finish line. False during intros, podiums and menus.
bool IsRacing()
{
	auto playground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
	if (playground is null || playground.GameTerminals.Length == 0) return false;
	auto sequence = playground.GameTerminals[0].UISequence_Current;
	return sequence == SGamePlaygroundUIConfig::EUISequence::Playing || sequence == SGamePlaygroundUIConfig::EUISequence::Finish;
}

// The local player, but only while their own car is on screen.
// Null in menus, while spectating someone else and while watching replays.
CSmPlayer@ GetLocalPlayer()
{
	auto playground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
	if (playground is null || playground.GameTerminals.Length == 0) return null;
	auto terminal = playground.GameTerminals[0];
	if (terminal.GUIPlayer !is terminal.ControlledPlayer) return null;
	return cast<CSmPlayer>(terminal.ControlledPlayer);
}

// Visual state of the player's car, refreshed by the game every rendered frame.
CSceneVehicleVisState@ GetCarState(CSmPlayer@ player)
{
	auto vis = VehicleState::GetVis(GetApp().GameScene, player);
	return vis is null ? null : vis.AsyncState;
}
