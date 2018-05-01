#pragma semicolon 1

#include <sourcemod>
#include <sdktools>


public Plugin myinfo = 
{
	name = "Report System",
	author = "KeidaS",
	description = "Report System for sourcemod servers",
	version = "1.0",
	url = "www.hermandadfenix.es"
};

char queryBuffer[3096];

Handle db = INVALID_HANDLE;

int reportId = 0;


public void OnPluginStart() {
	RegConsoleCmd("reportar", Report);
	RegAdminCmd("reportes", Reports, ADMFLAG_SLAY);
	//RegAdminCmd("desatender", ExitReport, ADMFLAG_SLAY);
	//RegAdminCmd("atendido", SolveReport, ADMFLAG_SLAY);
	ConnectDB();
}

public void ConnectDB() {
	char error[255];
	db = SQL_Connect("rankme", true, error, sizeof(error));
	
	if (db == INVALID_HANDLE) {
		LogError("ERROR CONNECTING TO THE DB");
	} else {
		Format(queryBuffer, sizeof(queryBuffer), "CREATE TABLE IF NOT EXISTS reports (reportId INTEGER PRIMARY KEY NOT NULL, reporter varchar(64) NOT NULL, reported varchar(64) NOT NULL, reason varchar(64), attendedBy varchar(64))");
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
				COMMAND_FILTER_NO_IMMUNITY,
				target_name,
				sizeof(target_name),
				tn_is_ml);
		if (target_count <= 0) {
			PrintToChat(client, "No hay ningún usuario con ese nombre");
			return Plugin_Handled;
		} else if (target_count == 1) {
			if (!IsFakeClient(target_list[0])) {
				char query[254];
				char name1[64];
				GetClientName(target_list[0], name1, sizeof(name1));
				GetClientName(client, name, sizeof(name));
				PrintToChatAll("\x02 \x02 %s \x02 ha \x02 reportado \x02 a \x02 %s \x02 por \x02 %s", name, name1, arguments[len]);
				Format(query, sizeof(query), "INSERT INTO reports VALUES ('%i', '%s', '%s', '%s', 'null')", reportId, name, name1, arguments[len]);
				SQL_TQuery(db, InsertReportCallback, query, _);
				return Plugin_Continue;	
			} else {
				return Plugin_Handled;
			}
		} else {
			PrintToChat(client, "Hay más de un usuario con ese nombre");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
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
	if (action == MenuAction_Select) {
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		Menu reasons = new Menu(MenuHandler_ReasonMenu, MenuAction_Start | MenuAction_Select | MenuAction_Cancel | MenuAction_End);
		reasons.SetTitle("Razón para reportar a %s :", info);
		reasons.AddItem("Free Kill", "Free Kill");
		reasons.AddItem("Insultar / Faltar al respeto", "Insultar / Faltar al respeto");
		reasons.AddItem("Actitud tóxica", "Actitud tóxica");
		reasons.AddItem("Entrar a conducto", "Entrar a conducto");
		reasons.AddItem("Disparar balón", "Disparar balón");
		reasons.AddItem("Jugar a juegos", "Juegar a juegos");
		reasons.Display(param1, 20);
		reasons.AddItem(info, info);
	}
}

public int MenuHandler_ReasonMenu(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char query[256];
		char name[64];
		char info[64];
		char name1[64];
		menu.GetItem(param2, info, sizeof(info));
		GetMenuItem(menu, 6, name1, sizeof(name1));
		GetClientName(param1, name, sizeof(name));
		PrintToChatAll("\x02 \x02 %s \x02 ha \x02 reportado \x02 a \x02 %s \x02 por \x02 %s", name, name1, info);
		Format(query, sizeof(query), "INSERT INTO reports VALUES ('%i', '%s', '%s', '%s', 'null')", reportId, name, name1, info);
		SQL_TQuery(db, InsertReportCallback, query, _);
	}
}

public void InsertReportCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR INSERTING THE REPORT");
		LogError("%i", error);
	} else {
		reportId++;
	}
}

public void OnMapEnd() {
	reportId = 0;
	char query[256];
	Format(query, sizeof(query), "DELETE FROM reports");
	SQL_TQuery(db, OnMapEndCallback, query, _);
}

public void OnMapEndCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR CLEANING THE TABLE");
		LogError("%i", error);
	}
}

public Action:Reports(int client, int args) {
	char query[254];
	Format(query, sizeof(query), "SELECT reporter, reported, reason, attendedBy, reportId FROM reports ORDER BY reportId ASC");
	SQL_TQuery(db, ReportsCallback, query, GetClientUserId(client));
}

public void ReportsCallback(Handle owner, Handle hndl, char[] error, any data) {
	int client = GetClientOfUserId(data);
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR GETTING THE REPORTS");
		LogError("%i", error);
	} else {
		char name[64];
		char name1[64];
		char reason[256];
		char item[256];
		char admin[64];
		int id = 0;
		Menu menu = new Menu(MenuHandler_Reports, MenuAction_Start | MenuAction_Select | MenuAction_End | MenuAction_Cancel);
		menu.SetTitle("Reportes");
		while (SQL_FetchRow(hndl)) {
			SQL_FetchString(hndl, 0, name, sizeof(name));
			SQL_FetchString(hndl, 1, name1, sizeof(name1));
			SQL_FetchString(hndl, 2, reason, sizeof(reason));
			SQL_FetchString(hndl, 3, admin, sizeof(admin));
			id = SQL_FetchInt(hndl, 4);
			if (StrEqual(admin, "null")) {
				Format(item, sizeof(item), "%i %s ha reportado a %s por %s", id, name, name1, reason);
				menu.AddItem(item, item);
			} else {
				Format(item, sizeof(item), "%i %s ha reportado a %s por %s [ %s ]", id, name, name1, reason, admin);
				AddMenuItem(menu, "Item", item, ITEMDRAW_DISABLED);
			}
		}
		menu.Display(client, 20);
	}
}

public int MenuHandler_Reports(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char idS[4];
		char info[256];
		menu.GetItem(param2, info, sizeof(info));
		BreakString(info, idS, sizeof(idS));
		Menu report = new Menu(MenuHandler_AttendReport, MenuAction_Start | MenuAction_Select | MenuAction_End | MenuAction_Cancel);
		report.SetTitle("Reportes");
		report.AddItem("Atender", "Atender");
		report.AddItem("Borrar", "Borrar");
		report.Display(param1, 20);
		report.AddItem(idS, idS);
	}
}

public int MenuHandler_AttendReport(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		int id = 0;
		char idS[4];
		char info[64];
		char query[256];
		char name[64];
		menu.GetItem(param2, info, sizeof(info));
		GetMenuItem(menu, 2, idS, sizeof(idS));
		id = StringToInt(idS);
		if (StrEqual(info, "Atender")) {
			GetClientName(param1, name, sizeof(name));
			Format(query, sizeof(query), "UPDATE reports SET attendedBy = '%s' WHERE reportId = '%i'", name, id);
			PrintToChat(param1, "Te has encargado del reporte con ID: %i", id);
		} else if (StrEqual(info, "Borrar")) {
			Format(query, sizeof(query), "DELETE FROM reports WHERE reportId = '%i'", id);
			PrintToChat(param1, "Has borrado el reporte con ID: %i", id);
		}
		SQL_TQuery(db, AttendReportCallback, query, GetClientUserId(param1));
	}
}

public void AttendReportCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR ATTENDING THE REPORT");
		LogError("%i", error);
	}
}

/*
public Action:ExitReport(int client, int args) {
	if (args < 1) {
		return Plugin_Handled;
	} else {
		char idS[64];
		GetCmdArg(1, idS, sizeof(idS));
		int id = StringToInt(idS);
		char query[256];
		Format(query, sizeof(query), "SELECT attendedBy FROM reports WHERE reportId = '%i'", id);
		SQL_TQuery(db, ExitReportCallback, query, GetClientUserId(client));
		return Plugin_Continue;
	}
}

public void ExitReportCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR ATTENDING THE REPORT");
		LogError("%i", error);
	} else {
		char name[64];
		char name1[64];
		if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
			SQL_FetchString(hndl, 0, name, sizeof(name));
			int client = GetClientOfUserId(data);
			GetClientName(client, name1, sizeof(name1));
			if (StrEqual(name, name1)) {
				PrintToChat(client, "Can exit");
			}
		}
	}
}


public Action:SolveReport(int client, int args) {
	if (args < 1) {
		return Plugin_Handled;
	} else {
		char idS[64];
		GetCmdArg(1, idS, sizeof(idS));
		int id = StringToInt(idS);
		char query[256];
		Format(query, sizeof(query), "SELECT attendedBy, reporter, reported, reason FROM reports WHERE reportId = '%i'", id);
		SQL_TQuery(db, SolveReportCallback, query, GetClientUserId(client));
		return Plugin_Continue;
	}
}

public void SolveReportCallback(Handle owner, Handle hndl, char[] error, any data) {
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR ATTENDING THE REPORT");
		LogError("%i", error);
	} else {
		char name[64];
		char name1[64];
		int client = GetClientOfUserId(data);
		if (!SQL_FetchRow(hndl)) {
			PrintToChat(client, "oda2");
			SQL_FetchString(hndl, 0, name, sizeof(name));
			GetClientName(client, name1, sizeof(name1));
			if (StrEqual(name, name1)) {
				PrintToChat(client, "Can solve");
			}
		}
	}
}*/

