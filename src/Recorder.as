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
