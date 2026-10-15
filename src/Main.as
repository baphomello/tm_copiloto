[Setting name="Record runs" description="Automatically record telemetry of every run to the plugin storage folder."]
bool S_Record = true;

[Setting name="Show status window"]
bool S_ShowWindow = true;

void Main()
{
	print("Loaded version " + Meta::ExecutingPlugin().Version);
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
	}
	UI::End();
}
