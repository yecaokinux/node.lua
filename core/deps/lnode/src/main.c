/**
 *  Copyright 2016 The Node.lua Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
#include "lnode.h"

static int lnode_print_info(lua_State* L) {
  char script[] =
    "pcall(require, 'init')\n"
    "local lnode = require('lnode')\n"
    "print('NODE_LUA_ROOT:\\n' .. lnode.NODE_LUA_ROOT .. '\\n')\n"
    "local path = string.gsub(package.path, ';', '\\n')"
  	"print('package.path:\\n' .. path)\n"
    "local cpath = string.gsub(package.cpath, ';', '\\n')"
  	"print('package.cpath:\\n' .. cpath)\n"
  	;

  return lnode_call_script(L, script, "info.lua");
}

/**
 * Note that a Lua virtual machine can only be run in a single thread,
 * creating a new virtual machine for each new thread created.
 * This method runs at the beginning of each thread to create new Lua
 * virtual machines and register the associated built-in modules.
 */
static lua_State* lnode_vm_acquire() {
	lua_State* L = luaL_newstate();
	if (L == NULL) {
		return L;
	}

	luaL_openlibs(L);	// Add in the lua standard libraries
	lnode_openlibs(L);	// Add in the lnode lua ext libraries
	lnode_path_init(L);

	return L;
}

#if !defined(LUA_PROGNAME)
#define LUA_PROGNAME		"lua"
#endif

static const char *progname = LUA_PROGNAME;

static lua_State *globalL = NULL;

/*
** Prints an error message, adding the program name in front of it
** (if present)
*/
static void lnode_print_message (const char *pname, const char *msg) {
  	if (pname) {
		lua_writestringerror("%s: ", pname);
	}
  	lua_writestringerror("%s\n", msg);
}

/*
** Check whether 'status' is not OK and, if so, prints the error
** message on the top of the stack. It assumes that the error object
** is a string, as it was either generated by Lua or by 'lnode_message_handler'.
*/
static int lnode_report_message (lua_State *L, int status) {
  	if (status != LUA_OK) {
    	const char *msg = lua_tostring(L, -1);
    	lnode_print_message(progname, msg);
    	lua_pop(L, 1);  /* remove message */
  	}
  	return status;
}

/*
** Message handler used to run all chunks
*/
static int lnode_message_handler (lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL) {  /* is error object not a string? */
		if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
			lua_type(L, -1) == LUA_TSTRING) {  /* that produces a string? */
			return 1;  /* that is the message */
		} else {
			msg = lua_pushfstring(L, "(error object is a %s value)",
								luaL_typename(L, 1));
		}
	}
	
	luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
	return 1;  /* return the traceback */
}

/*
** Hook set by signal function to stop the interpreter.
*/
static void lnode_stop (lua_State *L, lua_Debug *ar) {
	(void)ar;  /* unused arg. */
	lua_sethook(L, NULL, 0, 0);  /* reset hook */
	luaL_error(L, "interrupted!");
}


/*
** Function to be called at a C signal. Because a C signal cannot
** just change a Lua state (as there is no proper synchronization),
** this function only sets a hook that, when called, will stop the
** interpreter.
*/
static void lnode_signal_handler (int i) {
  	signal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  	lua_sethook(globalL, lnode_stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/*
** Interface to 'lua_pcall', which sets appropriate message function
** and C-signal handler. Used to run all chunks.
*/
static int lnode_docall (lua_State *L, int narg, int nres) {
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_pushcfunction(L, lnode_message_handler);  /* push message handler */
	lua_insert(L, base);  /* put it under function and args */
	globalL = L;  /* to be available to 'lnode_signal_handler' */
	signal(SIGINT, lnode_signal_handler);  /* set C-signal handler */
	status = lua_pcall(L, narg, nres, base);
	signal(SIGINT, SIG_DFL); /* reset C-signal handler */
	lua_remove(L, base);  /* remove message handler from the stack */
	return status;
}

static int lnode_dochunk (lua_State *L, int status) {
  	if (status == LUA_OK) {
		status = lnode_docall(L, 0, 0);
	}

  	return lnode_report_message(L, status);
}

static int lnode_dofile (lua_State *L, const char *name) {
  	return lnode_dochunk(L, luaL_loadfile(L, name));
}

/*
** Calls 'require(name)' and stores the result in a global variable
** with the given name.
*/
static int lnode_dolibrary (lua_State *L, const char *name) {
  int status;
  lua_getglobal(L, "require");
  lua_pushstring(L, name);
  status = lnode_docall(L, 1, 1);  /* call 'require(name)' */
  if (status == LUA_OK) {
    lua_setglobal(L, name);  /* global[name] = require return */
  }
  return lnode_report_message(L, status);
}

/**
 * Call this method at the end of each thread to close the relevant Lua
 * virtual machine and release the associated resources.
 */
static void lnode_vm_release(lua_State* L) {
  	lua_close(L);
}

int main(int argc, char* argv[]) {
	lua_State* L 	= NULL;
	int index 		= 0;
	int res 		= 0;
	int script 		= 1;
	int has_eval	= 0;
	int has_info	= 0;
	int has_print	= 0;
	int has_script 	= 0;
	int has_require	= 0;
	int has_deamon  = 0;

#ifndef _WIN32
	signal(SIGPIPE, SIG_IGN);	// 13) 管道破裂: Write a pipe that does not have a read port

#endif
	
	// Hooks in libuv that need to be done in main.
	argv = uv_setup_args(argc, argv);

	if (argc >= 2) {
		const char* option = argv[1];

		if (strcmp(option, "-d") == 0) {
			// Runs the current script in the background
			lnode_run_as_deamon();
			script = 2;

		} else if (strcmp(option, "-l") == 0) {
			has_info = 1;

		} else if (strcmp(option, "-e") == 0) {
			script = 2;
			has_eval = 1;

		} else if (strcmp(option, "-p") == 0) {
			script = 2;
			has_print = 1;

		} else if (strcmp(option, "-r") == 0) {
			script = 2;
			has_require = 1;

		} else if (strcmp(option, "-v") == 0) {
			lnode_print_version();
			return 0;		

		} else if (strcmp(option, "-") == 0) {
			// Read Lua script content from the pipeline
			script = 2;
			has_script = 2;

		} else if (option[0] == '-') {
			script = 2;
		}
	}

	// filename
	const char* filename = NULL;
	if ((script > 0) && (script < argc)) {
		filename = argv[script];
		has_script = 1;
	}

	char pathBuffer[PATH_MAX];
	memset(pathBuffer, 0, PATH_MAX);

	// Create the lua state.
	L = luaL_newstate();
	if (L == NULL) {
		fprintf(stderr, "luaL_newstate has failed\n");
		return 1;
	}

	luaL_openlibs(L);  	// Add in the lua standard libraries
	lnode_openlibs(L); 	// Add in the lua ext libraries
	lnode_create_arg_table(L, argv, argc, script);

	luv_set_thread_cb(lnode_vm_acquire, lnode_vm_release);

	lnode_path_init(L);

	if (has_info) {
		lnode_print_info(L);

	} else if (has_eval) {
		if (filename) {
			lnode_dolibrary(L, "init");
			res = lnode_call_script(L, filename, "eval.lua");
		}

	} else if (has_print) {
		if (filename) {
			snprintf(pathBuffer, PATH_MAX, "print(%s)", filename);

			lnode_dolibrary(L, "init");
			res = lnode_call_script(L, pathBuffer, "print.lua");
		}
		
	} else if (has_require) {
		if (filename) {
			lnode_dolibrary(L, "init");
			res = lnode_dolibrary(L, filename);
		}

	} else if (has_script) {
		lnode_dolibrary(L, "init");

		res = lnode_dofile(L, filename);

		lnode_call_script(L, "runLoop()", "loop");
		lnode_call_script(L, "process:emit('exit')\n", "exit");

	} else {
		lnode_print_version();
		lnode_print_usage();
	}

	lnode_vm_release(L);
	return res;
}
