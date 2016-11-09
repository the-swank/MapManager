#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "3.0.0-154"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

#define FUNCTION_NEXTMAP //replace default nextmap
//#define FUNCTION_RTV
#define FUNCTION_NOMINATION
//#define FUNCTION_NIGHTMODE
#define FUNCTION_BLOCK_MAPS

#define SELECT_MAPS 5
#define PRE_START_TIME 3
#define VOTE_TIME 5

#define NOMINATED_MAPS_IN_VOTE 3
#define NOMINATED_MAPS_PER_PLAYER 3

#define BLOCK_MAP_COUNT 5

#define MIN_DENOMINATE_TIME 3 // seconds

new const PREFIX[] = "^4[MapManager]";

///**************************///

new const FILE_MAPS[] = "maps.ini"; //configdir

stock const FILE_BLOCKED_MAPS[] = "blockedmaps.ini"; //datadir

new const FILE_NIGHT_MAPS[] = "nightmaps.ini"; //configdir

///**************************///

#define MAX_ITEMS 8
#define MAP_NAME_LENGTH 32

///**************************///

enum _:MapsListStruct
{
	m_MapName[MAP_NAME_LENGTH],
	m_MinPlayers,
	m_MaxPlayers,
	m_BlockCount
};

enum MapsListIndexes
{
	MapsListEnd,
	NightListStart,
	NightListEnd
};

enum _:NominationStruct
{
	n_MapName[MAP_NAME_LENGTH],
	n_Player,
	n_MapIndex
};

enum _:VoteMenuStruct
{
	v_MapName[MAP_NAME_LENGTH],
	v_MapIndex,
	v_Votes
};

enum BlockLists
{
	DayList,
	NightList
};

enum Cvars
{
	CHANGE_TYPE,
	TIMELEFT_TO_VOTE,
	SHOW_RESULT_TYPE,
	SHOW_SELECTS,
	VOTE_IN_NEW_ROUND,
	LAST_ROUND,
	RESTORE_MAP_LIMITS,
	SHOW_PERCENT_AFTER_VOTE,
	SECOND_VOTE,
	SECOND_VOTE_PERCENT,
	SECOND_VOTE_DELAY,
	EXTENDED_TYPE,
	EXTENDED_MAX,
	EXTENDED_TIME,
	EXTENDED_ROUNDS,
#if defined FUNCTION_NOMINATION
	NOMINATION_DONT_CLOSE_MENU,
	NOMINATION_DEL_NON_CUR_ONLINE,
#endif // FUNCTION_NOMINATION
	MAXROUNDS,
	WINLIMIT,
	TIMELIMIT,
	FREEZETIME,
	CHATTIME,
	NEXTMAP,
};

enum Forwards
{
	_StartTimer,
	_TimerCount,
	_StartVote,
	_FinishVote,
	_StopVote
};

enum _:Tasks(+=100)
{
	TASK_TIMER = 150,
	TASK_CHECKTIME
};

enum
{
	SHOW_DISABLED,
	SHOW_MENU,
	SHOW_HUD
};

enum
{
	CHANGE_AFTER_VOTE,
	CHANGE_NEXT_ROUND,
	CHANGE_MAP_END
};

new g_pCvars[Cvars];
new g_hForward[Forwards];

new Array:g_aMapsList;
new g_iMapsListIndexes[MapsListIndexes];

new g_iBlockedMaps[BlockLists];

new bool:g_bVoteStarted;
new bool:g_bVoteFinished;

new g_eVoteMenu[SELECT_MAPS + 1][VoteMenuStruct];
new g_iVoteItems;
new g_iTotalVotes;

new g_iTimer;

new bool:g_bNight;

new bool:g_bPlayerVoted[33];

new g_szCurMap[MAP_NAME_LENGTH];

new g_bCanExtend;
new g_iExtendedNum;

new g_iTeamScore[2];

new bool:g_bSecondVote;

new Float:g_fOldTimeLimit;

new bool:g_bVoteInNewRound;

#if defined FUNCTION_NOMINATION
new Array:g_aNominationList;
new g_iNominatedMaps[33];
new g_iLastDenominate[33];
new Array:g_aMapsPrefixes;
new g_iMapsPrefixesNum;
#endif // FUNCTION_NOMINATION

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar("mapm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	g_pCvars[CHANGE_TYPE] = register_cvar("mapm_change_type", "0"); // 0 - after end vote, 1 - in round end, 2 - after end map
	g_pCvars[TIMELEFT_TO_VOTE] = register_cvar("mapm_timeleft_to_vote", "2"); // minutes
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mapm_show_result_type", "1"); //0 - disable, 1 - menu, 2 - hud
	g_pCvars[SHOW_SELECTS] = register_cvar("mapm_show_selects", "1"); // 0 - disable, 1 - all
	g_pCvars[VOTE_IN_NEW_ROUND] = register_cvar("mapm_vote_in_new_round", "0"); // 0 - disable, 1 - enable
	g_pCvars[LAST_ROUND] = register_cvar("mapm_last_round", "0"); //0 - disable, 1 - enable
	g_pCvars[RESTORE_MAP_LIMITS] = register_cvar("mapm_restore_map_limit", "1"); //0 - disable, 1 - enable
	g_pCvars[SHOW_PERCENT_AFTER_VOTE] = register_cvar("mapm_show_percent_after_vote", "0"); //0 - disable, 1 - enable

	g_pCvars[SECOND_VOTE] = register_cvar("mapm_second_vote", "0"); // 0 - disable, 1 - enable
	g_pCvars[SECOND_VOTE_PERCENT] = register_cvar("mapm_second_vote_percent", "50");
	g_pCvars[SECOND_VOTE_DELAY] = register_cvar("mapm_second_vote_delay", "5"); // seconds

	g_pCvars[EXTENDED_TYPE] = register_cvar("mapm_extended_type", "0"); // 0 - minutes, 1 - rounds
	g_pCvars[EXTENDED_MAX] = register_cvar("mapm_extended_map_max", "3");
	g_pCvars[EXTENDED_TIME] = register_cvar("mapm_extended_time", "15"); // minutes
	g_pCvars[EXTENDED_ROUNDS] = register_cvar("mapm_extended_rounds", "3"); // rounds
	
	#if defined FUNCTION_NOMINATION
	g_pCvars[NOMINATION_DONT_CLOSE_MENU] = register_cvar("mapm_nom_dont_close_menu", "0");// 0 - disable, 1 - enable
	g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE] = register_cvar("mapm_nom_del_noncur_online", "0");// 0 - disable, 1 - enable
	#endif

	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	g_pCvars[FREEZETIME] = get_cvar_pointer("mp_freezetime");

	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif // FUNCTION_NEXTMAP

	register_concmd("mapm_debug", "Command_Debug", ADMIN_MAP);
	register_concmd("mapm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mapm_stopvote", "Command_StopVote", ADMIN_MAP);

	#if defined FUNCTION_NOMINATION
	register_clcmd("say", "Command_Say");
	register_clcmd("say_team", "Command_Say");
	register_clcmd("say maps", "Command_MapsList");
	register_clcmd("say /maps", "Command_MapsList");
	#endif // FUNCTION_NOMINATION

	g_hForward[_StartTimer] = CreateMultiForward("mapmanager_start_timer", ET_IGNORE);
	g_hForward[_TimerCount] = CreateMultiForward("mapmanager_timer_count", ET_IGNORE, FP_CELL);
	g_hForward[_StartVote] = CreateMultiForward("mapmanager_start_vote", ET_IGNORE);
	g_hForward[_FinishVote] = CreateMultiForward("mapmanager_finish_vote", ET_IGNORE);
	g_hForward[_StopVote] = CreateMultiForward("mapmanager_stop_vote", ET_IGNORE);

	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");

	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "Event_Restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");

	#if defined FUNCTION_NEXTMAP
	register_event("30", "Event_Intermisson", "a");
	#endif // FUNCTION_NEXTMAP

	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
}
public plugin_cfg()
{
	g_aMapsList = ArrayCreate(MapsListStruct);

	#if defined FUNCTION_NOMINATION
	g_aMapsPrefixes = ArrayCreate(MAP_NAME_LENGTH);
	g_aNominationList = ArrayCreate(NominationStruct);
	#endif // FUNCTION_NOMINATION

	

	#if defined FUNCTION_BLOCK_MAPS
	new Trie:trie_blocked_maps = TrieCreate();
	LoadBlockedMaps(trie_blocked_maps);
	#else
	new Trie:trie_blocked_maps;
	#endif // FUNCTION_BLOCK_MAPS

	LoadMapFile(trie_blocked_maps, false);
	LoadMapFile(trie_blocked_maps, true);

	#if defined FUNCTION_BLOCK_MAPS
	TrieDestroy(trie_blocked_maps);
	#endif // FUNCTION_BLOCK_MAPS

	register_dictionary("mapmanager.txt");

	if( is_plugin_loaded("Nextmap Chooser") > -1 )
	{
		pause("cd", "mapchooser.amxx");
		log_amx("MapManager: mapchooser.amxx has been stopped.");
	}

	#if defined FUNCTION_NEXTMAP
	if( is_plugin_loaded("NextMap") > -1 )
	{
		pause("cd", "nextmap.amxx");
		log_amx("MapManager: nextmap.amxx has been stopped.");
	}
	#endif // FUNCTION_NEXTMAP
}

#if defined FUNCTION_BLOCK_MAPS
LoadBlockedMaps(Trie:trie_blocked_maps)
{
	new file_dir[128]; get_localinfo("amxx_datadir", file_dir, charsmax(file_dir));
	new file_path[128]; formatex(file_path, charsmax(file_path), "%s/%s", file_dir, FILE_BLOCKED_MAPS);

	new cur_map[MAP_NAME_LENGTH]; get_mapname(cur_map, charsmax(cur_map)); strtolower(cur_map);
	copy(g_szCurMap, charsmax(g_szCurMap), cur_map);
	
	TrieSetCell(trie_blocked_maps, cur_map, 1);

	new file, temp;

	if(file_exists(file_path))
	{
		new temp_file_path[128]; formatex(temp_file_path, charsmax(temp_file_path), "%s/temp.ini", file_dir);
		file = fopen(file_path, "rt");
		temp = fopen(temp_file_path, "wt");

		new buffer[40], map[MAP_NAME_LENGTH], str_count[8], count;
		
		while(!feof(file))
		{
			fgets(file, buffer, charsmax(buffer));
			parse(buffer, map, charsmax(map), str_count, charsmax(str_count));

			strtolower(map);
			
			if(!is_map_valid(map) || TrieKeyExists(trie_blocked_maps, map)) continue;
			
			count = str_to_num(str_count) - 1;
			
			if(count <= 0) continue;
			
			if(count > BLOCK_MAP_COUNT)
			{
				count = BLOCK_MAP_COUNT;
			}

			fprintf(temp, "^"%s^" ^"%d^"^n", map, count);
			
			TrieSetCell(trie_blocked_maps, map, count);
		}
		
		fprintf(temp, "^"%s^" ^"%d^"^n", cur_map, BLOCK_MAP_COUNT);
		
		fclose(file);
		fclose(temp);
		
		delete_file(file_path);
		rename_file(temp_file_path, file_path, 1);
	}
	else
	{
		file = fopen(file_path, "wt");
		if(file)
		{
			fprintf(file, "^"%s^" ^"%d^"^n", cur_map, BLOCK_MAP_COUNT);
		}
		fclose(file);
	}
}
#endif // FUNCTION_BLOCK_MAPS

public LoadMapFile(Trie:trie_blocked_maps, load_night_maps)
{
	new file_path[128]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
	format(file_path, charsmax(file_path), "%s/%s", file_path, load_night_maps ? FILE_NIGHT_MAPS : FILE_MAPS);

	if(!load_night_maps && !file_exists(file_path))
	{
		set_fail_state("Maps file doesn't exist.");
	}

	if(load_night_maps)
	{
		g_iMapsListIndexes[NightListStart] = ArraySize(g_aMapsList);
	}

	new cur_map[MAP_NAME_LENGTH]; get_mapname(cur_map, charsmax(cur_map));
	new file = fopen(file_path, "rt");
	
	if(file)
	{
		new map_info[MapsListStruct], text[48], map[MAP_NAME_LENGTH], min[3], max[3];
		new nextmap = false, founded_nextmap = false;

		#if defined FUNCTION_NOMINATION
		new prefix[MAP_NAME_LENGTH];
		#endif

		while(!feof(file))
		{
			fgets(file, text, charsmax(text));
			parse(text, map, charsmax(map), min, charsmax(min), max, charsmax(max));
			
			strtolower(map);

			if(!map[0] || map[0] == ';' || !valid_map(map) || is_map_in_array(map, load_night_maps, true)) continue;
			
			if((load_night_maps && g_bNight || !load_night_maps && !g_bNight) && equali(map, cur_map))
			{
				nextmap = true;
				continue;
			}
			if(nextmap)
			{
				nextmap = false;
				founded_nextmap = true;
				set_pcvar_string(g_pCvars[NEXTMAP], map);
				server_print("founded nextmap: %s", map);
			}

			#if defined FUNCTION_NOMINATION
			if(get_map_prefix(map, prefix, charsmax(prefix)) && !is_prefix_in_array(prefix))
			{
				ArrayPushString(g_aMapsPrefixes, prefix);
				g_iMapsPrefixesNum++;
			}
			#endif // FUNCTION_NOMINATION
			
			map_info[m_MapName] = map;
			map_info[m_MinPlayers] = str_to_num(min);
			map_info[m_MaxPlayers] = str_to_num(max) == 0 ? 32 : str_to_num(max);
			
			#if defined FUNCTION_BLOCK_MAPS
			if(TrieKeyExists(trie_blocked_maps, map))
			{
				TrieGetCell(trie_blocked_maps, map, map_info[m_BlockCount]);
				g_iBlockedMaps[load_night_maps ? NightList : DayList]++;
			}
			#endif // FUNCTION_BLOCK_MAPS

			ArrayPushArray(g_aMapsList, map_info);
			min = ""; max = ""; map_info[m_BlockCount] = 0;
		}
		fclose(file);
		
		new size = ArraySize(g_aMapsList);

		if(!load_night_maps && size == 0)
		{
			set_fail_state("Nothing loaded from file.");
		}

		g_iMapsListIndexes[load_night_maps ? NightListEnd : MapsListEnd] = size;

		if(!founded_nextmap && (load_night_maps && g_bNight || !load_night_maps && !g_bNight))
		{
			new start = load_night_maps ? g_iMapsListIndexes[NightListStart] : 0;
			new end = load_night_maps ? g_iMapsListIndexes[NightListEnd] : g_iMapsListIndexes[MapsListEnd];
			new random_map = random_num(start, end - 1);
			ArrayGetArray(g_aMapsList, random_map, map_info);
			set_pcvar_string(g_pCvars[NEXTMAP], map_info[m_MapName]);
			server_print("don't found nextmap, random map: %s", map_info[m_MapName]);
		}
	}
}
public plugin_end()
{
	if(g_fOldTimeLimit > 0.0)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
	}

	restore_limits();
}
restore_limits()
{
	if(g_iExtendedNum)
	{
		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]))
		{
			new win_limit = get_pcvar_num(g_pCvars[WINLIMIT]);
			if(win_limit)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], win_limit - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]));
			}
			new max_rounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
			if(max_rounds)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], max_rounds - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]));
			}
		}
		else
		{
			new restored_value = get_pcvar_num(g_pCvars[TIMELIMIT]) - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_TIME]);
			set_pcvar_num(g_pCvars[TIMELIMIT], restored_value);
		}
		g_iExtendedNum = 0;
	}
}
public client_disconnect(id)
{
	#if defined FUNCTION_NOMINATION
	if(g_iNominatedMaps[id])
	{
		clear_nominated_maps(id);
	}
	#endif
}
public Task_CheckTime()
{
	if(g_bVoteStarted || g_bVoteFinished) return PLUGIN_CONTINUE;

	if(get_pcvar_float(g_pCvars[TIMELIMIT]) <= 0.0) return PLUGIN_CONTINUE;

	new Float:time_to_vote = get_pcvar_float(g_pCvars[TIMELEFT_TO_VOTE]);
	
	new timeleft = get_timeleft();
	if(timeleft <= floatround(time_to_vote * 60.0))
	{
		log_amx("SetVoteStart: timeleft %d", timeleft);
		SetVoteStart();
	}
	
	return PLUGIN_CONTINUE;
}
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0] == 'C') ? 0 : 1] = read_data(2);
}
public Event_NewRound()
{
	new max_rounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
	if(!g_bVoteFinished && max_rounds && (g_iTeamScore[0] + g_iTeamScore[1]) >= max_rounds - 2)
	{
		log_amx("StartVote: maxrounds %d [%d]", max_rounds, g_iTeamScore[0] + g_iTeamScore[1]);
		PrepareVote(false);
	}
	
	new win_limit = get_pcvar_num(g_pCvars[WINLIMIT]) - 2;
	if(!g_bVoteFinished && win_limit > 0 && (g_iTeamScore[0] >= win_limit || g_iTeamScore[1] >= win_limit))
	{
		log_amx("StartVote: winlimit %d [CT: %d, T: %d]", win_limit, g_iTeamScore[0], g_iTeamScore[1]);
		PrepareVote(false);
	}

	if(g_bVoteInNewRound && !g_bVoteStarted)
	{
		log_amx("StartVote: timeleft %d, new round", get_timeleft());
		PrepareVote(false);
	}

	if(g_bVoteFinished && (get_pcvar_num(g_pCvars[CHANGE_TYPE]) == CHANGE_NEXT_ROUND || get_pcvar_num(g_pCvars[LAST_ROUND])))
	{
		new nextmap[MAP_NAME_LENGTH]; get_pcvar_string(g_pCvars[NEXTMAP], nextmap, charsmax(nextmap));
		client_print_color(0, print_team_default, "%s^1 %L^3 %s^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", nextmap);
		Intermission();
	}
}
public Event_Restart()
{
	if(get_pcvar_num(g_pCvars[RESTORE_MAP_LIMITS]))
	{
		restore_limits();
	}
}

#if defined FUNCTION_NEXTMAP
public Event_Intermisson()
{
	new Float:chat_time = get_pcvar_float(g_pCvars[CHATTIME]);
	set_pcvar_float(g_pCvars[CHATTIME], chat_time + 2.0);
	set_task(chat_time, "DelayedChange");
}
public DelayedChange()
{
	new nextmap[MAP_NAME_LENGTH]; get_pcvar_string(g_pCvars[NEXTMAP], nextmap, charsmax(nextmap));
	set_pcvar_float(g_pCvars[CHATTIME], get_pcvar_float(g_pCvars[CHATTIME]) - 2.0);
	server_cmd("changelevel %s", nextmap);
}
#endif // FUNCTION_NEXTMAP

#if defined FUNCTION_NOMINATION
public Command_Say(id)
{
	if(g_bVoteStarted || g_bVoteFinished) return;
	
	new text[MAP_NAME_LENGTH]; read_args(text, charsmax(text));
	remove_quotes(text); trim(text); strtolower(text);
	
	if(string_with_space(text)) return;
	
	new map_index = is_map_in_array(text, g_bNight);
	
	if(map_index)
	{
		NominateMap(id, text, map_index - 1);
	}
	else if(strlen(text) >= 4)
	{
		new buffer[MAP_NAME_LENGTH], prefix[MAP_NAME_LENGTH], Array:array_nominate_list = ArrayCreate(), array_size;
		for(new i; i < g_iMapsPrefixesNum; i++)
		{
			ArrayGetString(g_aMapsPrefixes, i, prefix, charsmax(prefix));
			formatex(buffer, charsmax(buffer), "%s%s", prefix, text);
			map_index = g_bNight ? g_iMapsListIndexes[NightListStart] : 0;
			while((map_index = find_similar_map(map_index, buffer)))
			{
				ArrayPushCell(array_nominate_list, map_index - 1);
				array_size++;
			}
		}
		
		if(array_size == 1)
		{
			map_index = ArrayGetCell(array_nominate_list, 0);
			new map_info[MapsListStruct]; ArrayGetArray(g_aMapsList, map_index, map_info);
			copy(buffer, charsmax(buffer), map_info[m_MapName]);
			NominateMap(id, buffer, map_index);
		}
		else if(array_size > 1)
		{
			Show_NominationList(id, array_nominate_list, array_size);
		}
		
		ArrayDestroy(array_nominate_list);
	}
}
public Show_NominationList(id, Array: array, size)
{
	new text[64]; formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_FAST_NOM");
	new menu = menu_create(text, "NominationList_Handler");
	new map_info[MapsListStruct], item_info[48], map_index, nominate_index;
	
	for(new i, str_num[6]; i < size; i++)
	{
		map_index = ArrayGetCell(array, i);
		ArrayGetArray(g_aMapsList, map_index, map_info);
		
		num_to_str(map_index, str_num, charsmax(str_num));
		nominate_index = is_map_nominated(map_index);
		
		if(map_info[m_BlockCount])
		{
			formatex(item_info, charsmax(item_info), "%s[\r%d\d]", map_info[m_MapName], map_info[m_BlockCount]);
			menu_additem(menu, item_info, str_num, (1 << 31));
		}
		else if(nominate_index)
		{
			new nom_info[NominationStruct]; ArrayGetArray(g_aNominationList, nominate_index - 1, nom_info);
			if(id == nom_info[n_Player])
			{
				formatex(item_info, charsmax(item_info), "%s[\y*\w]", map_info[m_MapName]);
				menu_additem(menu, item_info, str_num);
			}
			else
			{
				formatex(item_info, charsmax(item_info), "%s[\y*\d]", map_info[m_MapName]);
				menu_additem(menu, item_info, str_num, (1 << 31));
			}
		}
		else
		{
			menu_additem(menu, map_info[m_MapName], str_num);
		}
	}
	
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_BACK");
	menu_setprop(menu, MPROP_BACKNAME, text);
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, text);
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
	
	menu_display(id, menu);
}
public NominationList_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new item_info[8], item_name[MAP_NAME_LENGTH], access, callback;
	menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), item_name, charsmax(item_name), callback);
	
	new map_index = str_to_num(item_info);
	trim_bracket(item_name);
	new is_map_nominated = NominateMap(id, item_name, map_index);
	
	if(is_map_nominated == 2 || get_pcvar_num(g_pCvars[NOMINATION_DONT_CLOSE_MENU]))
	{
		if(is_map_nominated == 1)
		{
			new item_info[48]; formatex(item_info, charsmax(item_info), "%s[\y*\w]", item_name);
			menu_item_setname(menu, item, item_info);
		}
		else if(is_map_nominated == 2)
		{
			menu_item_setname(menu, item, item_name);
		}
		menu_display(id, menu);
	}
	else
	{
		menu_destroy(menu);
	}
	
	return PLUGIN_HANDLED;
}
NominateMap(id, map[MAP_NAME_LENGTH], map_index)
{
	new map_info[MapsListStruct]; ArrayGetArray(g_aMapsList, map_index, map_info);
	
	#if defined FUNCTION_BLOCK_MAPS
	if(map_info[m_BlockCount])
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "MAPM_NOM_NOT_AVAILABLE_MAP");
		return 0;
	}
	#endif
	
	new nom_info[NominationStruct];
	new name[32];	get_user_name(id, name, charsmax(name));
	
	new nominate_index = is_map_nominated(map_index);
	if(nominate_index)
	{
		ArrayGetArray(g_aNominationList, nominate_index - 1, nom_info);
		if(id == nom_info[n_Player])
		{
			new sys_time = get_systime();
			if(g_iLastDenominate[id] + MIN_DENOMINATE_TIME <= sys_time)
			{
				g_iLastDenominate[id] = sys_time;
				g_iNominatedMaps[id]--;
				ArrayDeleteItem(g_aNominationList, nominate_index - 1);
				
				client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_REMOVE_NOM", name, map);
				return 2;
			}
			client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "MAPM_NOM_SPAM");
			return 0;
		}
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "MAPM_NOM_ALREADY_NOM");
		return 0;
	}
	
	if(g_iNominatedMaps[id] >= NOMINATED_MAPS_PER_PLAYER)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "MAPM_NOM_CANT_NOM");
		return 0;
	}
	
	nom_info[n_MapName] = map;
	nom_info[n_Player] = id;
	nom_info[n_MapIndex] = map_index;
	ArrayPushArray(g_aNominationList, nom_info);
	
	g_iNominatedMaps[id]++;
	
	if(get_pcvar_num(g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE]))
	{
		new min_players = map_info[m_MinPlayers] == 0 ? 1 : map_info[m_MinPlayers];
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_MAP2", name, map, min_players, map_info[m_MaxPlayers]);
	}
	else
	{
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_MAP", name, map);
	}
	
	return 1;
}
public Command_MapsList(id)
{
	Show_MapsListMenu(id);
}
Show_MapsListMenu(id)
{
	new text[64]; formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_MAP_LIST");
	new menu = menu_create(text, "MapsListMenu_Handler");
	
	new map_info[MapsListStruct], item_info[48];
	new start = g_bNight ? g_iMapsListIndexes[NightListStart] : 0;
	new end = g_bNight ? g_iMapsListIndexes[NightListEnd] : g_iMapsListIndexes[MapsListEnd];
	
	for(new i = start, nominate_index; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		nominate_index = is_map_nominated(i);
		
		if(map_info[m_BlockCount])
		{
			formatex(item_info, charsmax(item_info), "%s[\r%d\d]", map_info[m_MapName], map_info[m_BlockCount]);
			menu_additem(menu, item_info, _, (1 << 31));
		}
		else if(nominate_index)
		{
			new nom_info[NominationStruct]; ArrayGetArray(g_aNominationList, nominate_index - 1, nom_info);
			if(id == nom_info[n_Player])
			{
				formatex(item_info, charsmax(item_info), "%s[\y*\w]", map_info[m_MapName]);
				menu_additem(menu, item_info);
			}
			else
			{
				formatex(item_info, charsmax(item_info), "%s[\y*\d]", map_info[m_MapName]);
				menu_additem(menu, item_info, _, (1 << 31));
			}
		}
		else
		{
			menu_additem(menu, map_info[m_MapName]);
		}
	}
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_BACK");
	menu_setprop(menu, MPROP_BACKNAME, text);
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, text);
	formatex(text, charsmax(text), "%L", LANG_PLAYER, "MAPM_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
	
	menu_display(id, menu);
}
public MapsListMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new item_info[2], item_name[MAP_NAME_LENGTH], access, callback;
	menu_item_getinfo(menu, item, access, item_info, charsmax(item_info), item_name, charsmax(item_name), callback);
	
	new map_index = item;
	trim_bracket(item_name);
	new is_map_nominated = NominateMap(id, item_name, map_index);
	
	if(g_iNominatedMaps[id] < NOMINATED_MAPS_PER_PLAYER || get_pcvar_num(g_pCvars[NOMINATION_DONT_CLOSE_MENU]))
	{
		if(is_map_nominated == 1)
		{
			new new_item_info[48]; formatex(new_item_info, charsmax(new_item_info), "%s[\y*\w]", item_name);
			menu_item_setname(menu, item, new_item_info);
		}
		else if(is_map_nominated == 2)
		{
			menu_item_setname(menu, item, item_name);
		}
		menu_display(id, menu, map_index / 7);
	}
	else
	{
		menu_destroy(menu);
	}
	
	return PLUGIN_HANDLED;
}
#endif // FUNCTION_NOMINATION

public Command_Debug(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	console_print(id, "^nLoaded maps:");	
	new map_info[MapsListStruct];
	for(new i; i < g_iMapsListIndexes[MapsListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		console_print(id, "%3d ^t%32s ^t%d^t%d^t%d", i + 1, map_info[m_MapName], map_info[m_MinPlayers], map_info[m_MaxPlayers], map_info[m_BlockCount]);
	}
	console_print(id, "Night maps:");
	for(new i = g_iMapsListIndexes[NightListStart]; i < g_iMapsListIndexes[NightListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		console_print(id, "%3d ^t%32s ^t%d^t%d^t%d", i + 1, map_info[m_MapName], map_info[m_MinPlayers], map_info[m_MaxPlayers], map_info[m_BlockCount]);
	}

	#if defined FUNCTION_NOMINATION
	console_print(id, "^nLoaded prefixes:");
	for(new i, prefix[MAP_NAME_LENGTH]; i < g_iMapsPrefixesNum; i++)
	{
		ArrayGetString(g_aMapsPrefixes, i, prefix, charsmax(prefix));
		console_print(id, "%s", prefix);
	}
	#endif // FUNCTION_NOMINATION

	return PLUGIN_HANDLED;
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	SetVoteStart();

	//TODO: log this

	return PLUGIN_HANDLED;
}
public Command_StopVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	//TODO: log this
	if(g_bVoteStarted)
	{
		new ret; ExecuteForward(g_hForward[_StopVote], ret);

		g_bVoteStarted = false;

		remove_task(TASK_TIMER);
		show_menu(0, 0, "^n", 1);

		new name[32]; get_user_name(id, name, charsmax(name));
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CANCEL_VOTE", id ? name : "Server");
		log_amx("StopVote: %s canceled vote.", name);
	}

	return PLUGIN_HANDLED;
}
SetVoteStart()
{
	if(get_pcvar_num(g_pCvars[VOTE_IN_NEW_ROUND]))
	{
		g_bVoteInNewRound = true;

		if((g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT])) > 0.0)
		{
			set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
		}

		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_VOTE_WILL_BEGIN");
		server_print("SetVoteStart: vote in new round");
	}
	else
	{
		PrepareVote(false);
	}
}
public PrepareVote(second_vote)
{
	if(g_bVoteStarted) return 0;

	new players_num = _get_players_num();

	if(!players_num)
	{
		return 0;
	}

	if(second_vote)
	{
		// vote with 2 top voted maps
		g_iVoteItems = 2;
		g_bCanExtend = false;

		server_print("Prepare second vote:");
		for(new i; i < g_iVoteItems; i++)
		{
			server_print("%d. %s", i + 1, g_eVoteMenu[i][v_MapName]);
		}

		StartTimerTask();

		return 1;
	}

	reset_vote_values();

	// standart vote
	new start = (g_bNight) ? g_iMapsListIndexes[NightListStart] : 0;
	new end = (g_bNight) ? g_iMapsListIndexes[NightListEnd] : g_iMapsListIndexes[MapsListEnd];

	new items = 0;
	new menu_max_items = min(min(end - start - g_iBlockedMaps[g_bNight ? NightList : DayList], SELECT_MAPS), MAX_ITEMS);

	if(menu_max_items <= 0)
	{
		//log_amx("PrepareVote: All maps are blocked.");
		return 0;
	}

	new Array:array_maps_range = ArrayCreate(VoteMenuStruct);
	new map_info[MapsListStruct];
	new vote_item_info[VoteMenuStruct];

	for(new i = start; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);

		if(!map_info[m_BlockCount] && map_info[m_MinPlayers] <= players_num <= map_info[m_MaxPlayers])
		{
			copy(vote_item_info[v_MapName], charsmax(vote_item_info[v_MapName]), map_info[m_MapName]);
			vote_item_info[v_MapIndex] = i;
			ArrayPushArray(array_maps_range, vote_item_info);
		}
	}

	#if defined FUNCTION_NOMINATION
	new nom_info[NominationStruct];
	
	if(get_pcvar_num(g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE]))
	{
		for(new i; i < ArraySize(g_aNominationList); i++)
		{
			ArrayGetArray(g_aNominationList, i, nom_info);
			ArrayGetArray(g_aMapsList, nom_info[n_MapIndex], map_info);
			
			if(players_num > map_info[m_MaxPlayers] || players_num < map_info[m_MinPlayers])
			{
				ArrayDeleteItem(g_aNominationList, i--);
			}
		}
	}
	
	new max_nominations = min(min(ArraySize(g_aNominationList), NOMINATED_MAPS_IN_VOTE), menu_max_items);
	
	for(new random_map; items < max_nominations; items++)
	{
		random_map = random_num(0, ArraySize(g_aNominationList) - 1);
		ArrayGetArray(g_aNominationList, random_map, nom_info);
		
		formatex(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), nom_info[n_MapName]);
		g_eVoteMenu[items][v_MapIndex] = nom_info[n_MapIndex];
		g_iNominatedMaps[nom_info[n_Player]]--;
		
		ArrayDeleteItem(g_aNominationList, random_map);
		
		new priority_index = is_map_in_priority(array_maps_range, nom_info[n_MapIndex]);
		if(priority_index)
		{
			ArrayDeleteItem(array_maps_range, priority_index - 1);
		}
	}
	#endif // FUNCTION_NOMINATION

	if(items < menu_max_items)
	{
		for(new random_map, size = ArraySize(array_maps_range); size && items < menu_max_items; items++)
		{
			random_map = random(size);
			ArrayGetArray(array_maps_range, random_map, vote_item_info);

			copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), vote_item_info[v_MapName]);
			g_eVoteMenu[items][v_MapIndex] = vote_item_info[v_MapIndex];

			ArrayDeleteItem(array_maps_range, random_map);
			size = ArraySize(array_maps_range);
		}
	}

	ArrayDestroy(array_maps_range);

	if(items < menu_max_items)
	{
		for(new random_map; items < menu_max_items; items++)
		{
			do {
				random_map = random_num(start, end - 1);
				ArrayGetArray(g_aMapsList, random_map, map_info);
			} while(map_info[m_BlockCount] || is_map_in_menu(random_map));

			copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), map_info[m_MapName]);
			g_eVoteMenu[items][v_MapIndex] = random_map;
		}
	}

	g_iVoteItems = items;

	if((g_bCanExtend = allow_map_extend()))
	{
		copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), g_szCurMap);
	}

	server_print("Prepare vote:");
	for(new i; i < items; i++)
	{
		server_print("%d. %s", i + 1, g_eVoteMenu[i][v_MapName]);
	}

	StartTimerTask();

	return 1;
}
allow_map_extend()
{
	new allowed = 0;
	new Float:timelimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
	new round_check = get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (get_pcvar_num(g_pCvars[MAXROUNDS]) || get_pcvar_num(g_pCvars[WINLIMIT]));

	if(get_pcvar_num(g_pCvars[EXTENDED_MAX]) > g_iExtendedNum && (timelimit > 0.0 || g_bVoteInNewRound && timelimit == 0.0 || round_check))
	{
		allowed = 1;
	}
	return allowed;
}
reset_vote_values()
{
	for(new i; i < sizeof(g_eVoteMenu); i++)
	{
		g_eVoteMenu[i][v_MapName] = "";
		g_eVoteMenu[i][v_MapIndex] = -1;
		g_eVoteMenu[i][v_Votes] = 0;
	}
	arrayset(g_bPlayerVoted, false, 33);
	g_iTotalVotes = 0;
	//TODO: Add reset for rtv
}
StartTimerTask()
{
	new ret; ExecuteForward(g_hForward[_StartTimer], ret);

	g_bVoteStarted = true;

	#if PRE_START_TIME > 0
	g_iTimer = PRE_START_TIME + 1;
	Task_PreStartTimer();
	#else
	StartVote();
	#endif
}
public Task_PreStartTimer()
{
	if(--g_iTimer > 0)
	{
		new ret; ExecuteForward(g_hForward[_TimerCount], ret, g_iTimer);
		set_task(1.0, "Task_PreStartTimer", TASK_TIMER);
	}
	else
	{
		StartVote();
	}
}
StartVote()
{
	new ret; ExecuteForward(g_hForward[_StartVote], ret);

	//Show menu
	//TODO: add option - show percent only after vote

	//Start timer for end vote
	g_iTimer = VOTE_TIME + 1;
	Task_VoteTimer();
}
public Task_VoteTimer()
{
	if(--g_iTimer > 0)
	{
		for(new id = 1; id < 33; id++)
		{
			if(!is_user_connected(id) || g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) == SHOW_DISABLED) continue;

			Show_VoteMenu(id);
		}
		set_task(1.0, "Task_VoteTimer", TASK_TIMER);
	}
	else
	{
		show_menu(0, 0, "^n", 1);
		FinishVote();
	}
}
public Show_VoteMenu(id)
{
	static menu[512];
	new len, keys, percent, item;

	new allow_percent = g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_PERCENT_AFTER_VOTE]) || !get_pcvar_num(g_pCvars[SHOW_PERCENT_AFTER_VOTE]);
	
	len = formatex(menu, charsmax(menu), "\y%L:^n^n", id, g_bPlayerVoted[id] ? "MAPM_MENU_VOTE_RESULTS" : "MAPM_MENU_CHOOSE_MAP");
	
	for(item = 0; item < g_iVoteItems + g_bCanExtend; item++)
	{
		len += formatex(menu[len], charsmax(menu) - len, "%s", (item == g_iVoteItems) ? "^n" : "");

		if(!g_bPlayerVoted[id])
		{
			len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s", item + 1, g_eVoteMenu[item][v_MapName]);
			keys |= (1 << item);
		}
		else
		{
			len += formatex(menu[len], charsmax(menu) - len, "\d%s", g_eVoteMenu[item][v_MapName]);
		}

		if(allow_percent)
		{
			percent = (g_iTotalVotes) ? floatround(g_eVoteMenu[item][v_Votes] * 100.0 / g_iTotalVotes) : 0;
			len += formatex(menu[len], charsmax(menu) - len, "\d[\r%d%%\d]", percent);
		}

		if(item == g_iVoteItems)
		{
			len += formatex(menu[len], charsmax(menu) - len, "\y[%L]^n", id, "MAPM_MENU_EXTEND");
		}
		else
		{
			len += formatex(menu[len], charsmax(menu) - len, "^n");
		}
	}

	len += formatex(menu[len], charsmax(menu) - len, "^n\d%L \r%d\d %L", id, "MAPM_MENU_LEFT", g_iTimer, id, "MAPM_SECONDS");

	if(!keys) keys = (1 << 9);

	if(g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) == SHOW_HUD)
	{
		while(replace(menu, charsmax(menu), "\r", "")){}
		while(replace(menu, charsmax(menu), "\d", "")){}
		while(replace(menu, charsmax(menu), "\w", "")){}
		while(replace(menu, charsmax(menu), "\y", "")){}
		
		set_hudmessage(0, 55, 255, 0.02, -1.0, 0, 6.0, 1.0, 0.1, 0.2, 4);
		show_hudmessage(id, "%s", menu);
	}
	else
	{
		show_menu(id, keys, menu, -1, "VoteMenu");
	}
}
public VoteMenu_Handler(id, key)
{
	if(g_bPlayerVoted[id])
	{
		Show_VoteMenu(id);
		return PLUGIN_HANDLED;
	}
	
	g_eVoteMenu[key][v_Votes]++;
	g_iTotalVotes++;
	g_bPlayerVoted[id] = true;

	if(get_pcvar_num(g_pCvars[SHOW_SELECTS]))
	{
		new name[32]; get_user_name(id, name, charsmax(name));
		if(key == g_iVoteItems)
		{
			client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CHOSE_EXTEND", name);
		}
		else
		{
			client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CHOSE_MAP", name, g_eVoteMenu[key][v_MapName]);
		}
	}

	if(get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) != SHOW_DISABLED)
	{
		Show_VoteMenu(id);
	}
	
	return PLUGIN_HANDLED;
}
FinishVote()
{
	new ret; ExecuteForward(g_hForward[_FinishVote], ret);

	g_bVoteStarted = false;
	g_bVoteFinished = true;

	server_print("Vote finished");
	//Check votes
	new max_vote = 0;
	for(new i = 1; i < g_iVoteItems + 1; i++)
	{
		if(g_eVoteMenu[max_vote][v_Votes] < g_eVoteMenu[i][v_Votes]) max_vote = i;
	}

	if(max_vote == g_iVoteItems)
	{
		// map extended
		g_bVoteInNewRound = false;
		g_bVoteFinished = false;
		g_iExtendedNum++;

		//TODO: add reset for rtv values

		if(g_fOldTimeLimit > 0.0)
		{
			set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
			g_fOldTimeLimit = 0.0;
		}

		new win_limit = get_pcvar_num(g_pCvars[WINLIMIT]);
		new max_rounds = get_pcvar_num(g_pCvars[MAXROUNDS]);

		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (win_limit || max_rounds))
		{
			new rounds = get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]);
			
			if(win_limit > 0)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], win_limit + rounds);
			}
			if(max_rounds > 0)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], max_rounds + rounds);
			}
			
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", rounds, LANG_PLAYER, "MAPM_ROUNDS");
		}
		else
		{
			new min = get_pcvar_num(g_pCvars[EXTENDED_TIME]);
			
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", min, LANG_PLAYER, "MAPM_MINUTES");
			set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(min));
		}

		server_print("map extended");
		return 1;
	}

	new percent = floatround(g_eVoteMenu[max_vote][v_Votes] * 100.0 / g_iTotalVotes);

	if(!g_bSecondVote && g_eVoteMenu[max_vote][v_Votes] && get_pcvar_num(g_pCvars[SECOND_VOTE]) && percent < get_pcvar_num(g_pCvars[SECOND_VOTE_PERCENT]))
	{
		server_print("second vote");

		g_bSecondVote = true;
		g_bVoteFinished = false;
		g_bVoteInNewRound = false;

		if(max_vote != 0) change_vote_items(max_vote, 0);
		max_vote = 1;
		for(new i = 1; i < g_iVoteItems; i++)
		{
			if(g_eVoteMenu[max_vote][v_Votes] < g_eVoteMenu[i][v_Votes]) max_vote = i;
			g_eVoteMenu[i - 1][v_Votes] = 0;
		}
		if(max_vote != 1) change_vote_items(max_vote, 1);

		g_iTotalVotes = 0;
		arrayset(g_bPlayerVoted, false, 33);

		client_print_color(0, print_team_default, "%s^1 Second vote will start in %d seconds.", PREFIX, get_pcvar_num(g_pCvars[SECOND_VOTE_DELAY]));

		set_task(get_pcvar_float(g_pCvars[SECOND_VOTE_DELAY]), "PrepareVote", true);
		return 1;
	}

	g_bSecondVote = false;

	if(g_bVoteInNewRound && g_fOldTimeLimit > 0.0 && get_pcvar_num(g_pCvars[CHANGE_TYPE]) != CHANGE_NEXT_ROUND)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
		g_fOldTimeLimit = 0.0;
	}
	g_bVoteInNewRound = false;

	new timeleft = get_timeleft();
	server_print("VOTE END: timeleft after finish vote %d", timeleft);

	if(!g_eVoteMenu[max_vote][v_Votes])
	{
		// no one voted
		max_vote = random(g_iVoteItems);
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOBODY_VOTE", g_eVoteMenu[max_vote][v_MapName]);
		server_print("no one voted, random next map %s", g_eVoteMenu[max_vote][v_MapName]);
	}
	else
	{
		client_print_color(0, print_team_default, "%s^1 %L^3 %s^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", g_eVoteMenu[max_vote][v_MapName]);
	}

	server_print("max vote map %s, votes %d", g_eVoteMenu[max_vote][v_MapName], g_eVoteMenu[max_vote][v_Votes]);

	set_pcvar_string(g_pCvars[NEXTMAP], g_eVoteMenu[max_vote][v_MapName]);

	if(get_pcvar_num(g_pCvars[LAST_ROUND]))
	{
		g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
		set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_LASTROUND");
	}
	else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == CHANGE_AFTER_VOTE)
	{
		new sec = get_pcvar_num(g_pCvars[CHATTIME]);
		client_print_color(0, print_team_default, "%s^1 %L^1 %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_CHANGE", sec, LANG_PLAYER, "MAPM_SECONDS");
		Intermission();
	}
	else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == CHANGE_NEXT_ROUND)
	{
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_MAP_CHANGE_NEXTROUND");
	}

	return 1;
}
stock valid_map(map[])
{
	if(is_map_valid(map)) return true;
	
	new len = strlen(map) - 4;
	
	if(len < 0) return false;
	
	if(equali(map[len], ".bsp"))
	{
		map[len] = '^0';
		if(is_map_valid(map)) return true;
	}
	
	return false;
}
is_map_in_array(map[], night_maps, load = false)
{
	new start = night_maps ? g_iMapsListIndexes[NightListStart] : 0;
	new end = (night_maps || load) ? ArraySize(g_aMapsList) : g_iMapsListIndexes[MapsListEnd];
	new map_info[MapsListStruct];
	for(new i = start; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		if(equali(map, map_info[m_MapName])) return i + 1;
	}
	return 0;
}
_get_players_num()
{
	new players[32], pnum; get_players(players, pnum, "ch");
	return pnum;
}
is_map_in_menu(index)
{
	for(new i; i < sizeof(g_eVoteMenu); i++)
	{
		if(g_eVoteMenu[i][v_MapIndex] == index) return true;
	}
	return false;
}
change_vote_items(first, second)
{
	new vote_info[VoteMenuStruct];
	mem_copy(vote_info, g_eVoteMenu[second], VoteMenuStruct);
	mem_copy(g_eVoteMenu[second], g_eVoteMenu[first], VoteMenuStruct);
	mem_copy(g_eVoteMenu[first], vote_info, VoteMenuStruct);
}
mem_copy(dest[], const source[], size)
{
	for(new i; i < size; i++)
	{
		dest[i] = source[i];
	}
}

#if defined FUNCTION_NOMINATION
is_prefix_in_array(prefix[])
{
	for(new i, str[MAP_NAME_LENGTH]; i < g_iMapsPrefixesNum; i++)
	{
		ArrayGetString(g_aMapsPrefixes, i, str, charsmax(str));
		if(equali(prefix, str)) return true;
	}
	return false;
}
get_map_prefix(map[], prefix[], size)
{
	copy(prefix, size, map);
	for(new i; prefix[i]; i++)
	{
		if(prefix[i] == '_')
		{
			prefix[i + 1] = 0;
			return 1;
		}
	}
	return 0;
}
is_map_nominated(map_index)
{
	new nom_info[NominationStruct], size = ArraySize(g_aNominationList);
	for(new i; i < size; i++)
	{
		ArrayGetArray(g_aNominationList, i, nom_info);
		if(map_index == nom_info[n_MapIndex])
		{
			return i + 1;
		}
	}
	return 0;
}
is_map_in_priority(Array:array_priority, map_index)
{
	new priority_info[VoteMenuStruct], size = ArraySize(array_priority);
	for(new i; i < size; i++)
	{
		ArrayGetArray(array_priority, i, priority_info);
		if(map_index == priority_info[v_MapIndex])
		{
			return i + 1;
		}
	}
	return 0;
}
clear_nominated_maps(id)
{
	new nom_info[NominationStruct];
	for(new i = 0; i < ArraySize(g_aNominationList); i++)
	{
		ArrayGetArray(g_aNominationList, i, nom_info);
		if(id == nom_info[n_Player])
		{
			ArrayDeleteItem(g_aNominationList, i--);
			if(!--g_iNominatedMaps[id]) break;
		}
	}
}
find_similar_map(map_index, string[MAP_NAME_LENGTH])
{
	new map_info[MapsListStruct];
	new end = g_bNight ? g_iMapsListIndexes[NightListEnd] : g_iMapsListIndexes[MapsListEnd];

	for(new i = map_index; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		if(containi(map_info[m_MapName], string) != -1)
		{
			return i + 1;
		}
	}
	return 0;
}
trim_bracket(text[])
{
	for(new i; text[i]; i++)
	{
		if(text[i] == '[')
		{
			text[i] = 0;
			break;
		}
	}
}
string_with_space(string[])
{
	for(new i; string[i]; i++)
	{
		if(string[i] == ' ') return 1;
	}
	return 0;
}
#endif // FUNCTION_NOMINATION

stock Intermission()
{
	emessage_begin(MSG_ALL, SVC_INTERMISSION);
	emessage_end();
}
