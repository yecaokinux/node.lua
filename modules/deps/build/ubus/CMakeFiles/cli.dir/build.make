# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 2.8

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list

# Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The program to use to edit the cache.
CMAKE_EDIT_COMMAND = /usr/bin/ccmake

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /mnt/c/work/node.lua.tour/modules/deps/ubus

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mnt/c/work/node.lua.tour/modules/deps/build/ubus

# Include any dependencies generated for this target.
include CMakeFiles/cli.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/cli.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/cli.dir/flags.make

CMakeFiles/cli.dir/cli.c.o: CMakeFiles/cli.dir/flags.make
CMakeFiles/cli.dir/cli.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/cli.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/cli.dir/cli.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/cli.dir/cli.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/cli.c

CMakeFiles/cli.dir/cli.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/cli.dir/cli.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/cli.c > CMakeFiles/cli.dir/cli.c.i

CMakeFiles/cli.dir/cli.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/cli.dir/cli.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/cli.c -o CMakeFiles/cli.dir/cli.c.s

CMakeFiles/cli.dir/cli.c.o.requires:
.PHONY : CMakeFiles/cli.dir/cli.c.o.requires

CMakeFiles/cli.dir/cli.c.o.provides: CMakeFiles/cli.dir/cli.c.o.requires
	$(MAKE) -f CMakeFiles/cli.dir/build.make CMakeFiles/cli.dir/cli.c.o.provides.build
.PHONY : CMakeFiles/cli.dir/cli.c.o.provides

CMakeFiles/cli.dir/cli.c.o.provides.build: CMakeFiles/cli.dir/cli.c.o

# Object files for target cli
cli_OBJECTS = \
"CMakeFiles/cli.dir/cli.c.o"

# External object files for target cli
cli_EXTERNAL_OBJECTS =

ubus: CMakeFiles/cli.dir/cli.c.o
ubus: CMakeFiles/cli.dir/build.make
ubus: libubus.so
ubus: CMakeFiles/cli.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking C executable ubus"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/cli.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/cli.dir/build: ubus
.PHONY : CMakeFiles/cli.dir/build

CMakeFiles/cli.dir/requires: CMakeFiles/cli.dir/cli.c.o.requires
.PHONY : CMakeFiles/cli.dir/requires

CMakeFiles/cli.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/cli.dir/cmake_clean.cmake
.PHONY : CMakeFiles/cli.dir/clean

CMakeFiles/cli.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/deps/build/ubus && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/deps/ubus /mnt/c/work/node.lua.tour/modules/deps/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles/cli.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/cli.dir/depend
