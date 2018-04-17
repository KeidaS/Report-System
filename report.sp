#pragma semicolon 1

#include <sourcemod>
#include <sdktools>


public Plugin myinfo = 
{
	name = "Report System",
	author = "KeidaS",
	description = "Report System por sourcemod servers",
	version = "1.0",
	url = "www.hermandadfenix.es"
};

char queryBuffer[3096];

Handle db = INVALID_HANDLE;

int reportId = 0;


public void OnPluginStart() {
	RegConsoleCmd("reportar", Report);
	ConnectDB();
}

public void ConnectDB() {
	char error[255];
	db = SQL_Connect("rankme", true, error, sizeof(error));
	
	if (db == INVALID_HANDLE) {
		LogError("ERROR CONNECTING TO THE DB");
	} else {
		Format(queryBuffer, sizeof(queryBuffer), "CREATE TABLE IF NOT EXISTS reports (reportId INTEGER PRIMARY KEY NOT NULL, reporter varchar(64) NOT NULL, reported varchar(64) NOT NULL, reason varchar(64))");
		SQL_TQuery(db, ConnectDBCallback, queryBuffer);
	}
}

public void ConnectDBCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR CREATING THE TABLE");
		LogError("%s", error);
	}
}

public Action:Report(int client, int args) {
	char name[64];
	char arguments[256];
	int len;
	if (args == 0) {
		Show_ReportMenu(client);
	} else if (args == 1) {
		ReplyToCommand(client, "[SM] Uso: !reportar <nombre> <motivo>");
	} else {
		GetCmdArgString(arguments, sizeof(arguments));
		len = BreakString(arguments, name, sizeof(name));
		decl String:target_name[MAX_TARGET_LENGTH];
		new target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
		target_count = ProcessTargetString(
				name,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_CONNECTED,
				target_name,
				sizeof(target_name),
				tn_is_ml);
		if (target_count < 1) {
			PrintToChat(client, "No hay ningún usuario con ese nombre");
			return Plugin_Handled;
		} else if (target_count == 1) {
			if (!IsFakeClient(target_list[0])) {
				char query[254];
				char name1[64];
				GetClientName(target_list[0], name1, sizeof(name1));
				GetClientName(client, name, sizeof(name));
				Format(query, sizeof(query), "INSERT INTO reports VALUES ('%i', '%s', '%s', '%s')", reportId, name, name1, arguments);
				PrintToChatAll("%s ha reportado a %s. Motivo: %s", name, name1, arguments[len]);
				return Plugin_Continue;	
			} else {
				return Plugin_Handled;
			}
		} else {
			PrintToChat(client, "Hay más de un usuario con ese nombre");
			return Plugin_Handled;
		}
	}
}

public void Show_ReportMenu(int client) {
	char name[64];
	Menu menu = new Menu(MenuHandler_InitialMenu, MenuAction_Start | MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	menu.SetTitle("Select a player to report:");
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (IsClientConnected(i) && IsClientInGame(i)) {
			if (!IsFakeClient(i)) {
				GetClientName(i, name, sizeof(name));
				menu.AddItem(name, name);
			}
		}
	}
	menu.Display(client, 20);
}

public int MenuHandler_InitialMenu(Menu menu, MenuAction action, int param1, int param2) {

}