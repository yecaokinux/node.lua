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
CMAKE_SOURCE_DIR = /mnt/c/work/node.lua.tour/modules/ubus

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mnt/c/work/node.lua.tour/modules/ubus/build

# Include any dependencies generated for this target.
include libubox/examples/CMakeFiles/ustream-example.dir/depend.make

# Include the progress variables for this target.
include libubox/examples/CMakeFiles/ustream-example.dir/progress.make

# Include the compile flags for this target's objects.
include libubox/examples/CMakeFiles/ustream-example.dir/flags.make

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o: libubox/examples/CMakeFiles/ustream-example.dir/flags.make
libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o: ../libubox/examples/ustream-example.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/ubus/build/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ustream-example.dir/ustream-example.c.o   -c /mnt/c/work/node.lua.tour/modules/ubus/libubox/examples/ustream-example.c

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ustream-example.dir/ustream-example.c.i"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/ubus/libubox/examples/ustream-example.c > CMakeFiles/ustream-example.dir/ustream-example.c.i

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ustream-example.dir/ustream-example.c.s"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples && /usr/bin/cc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/ubus/libubox/examples/ustream-example.c -o CMakeFiles/ustream-example.dir/ustream-example.c.s

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.requires:
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.requires

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.provides: libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.requires
	$(MAKE) -f libubox/examples/CMakeFiles/ustream-example.dir/build.make libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.provides.build
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.provides

libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.provides.build: libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o

# Object files for target ustream-example
ustream__example_OBJECTS = \
"CMakeFiles/ustream-example.dir/ustream-example.c.o"

# External object files for target ustream-example
ustream__example_EXTERNAL_OBJECTS =

libubox/examples/ustream-example: libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o
libubox/examples/ustream-example: libubox/examples/CMakeFiles/ustream-example.dir/build.make
libubox/examples/ustream-example: libubox/libubox.so
libubox/examples/ustream-example: libubox/examples/CMakeFiles/ustream-example.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking C executable ustream-example"
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/ustream-example.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
libubox/examples/CMakeFiles/ustream-example.dir/build: libubox/examples/ustream-example
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/build

libubox/examples/CMakeFiles/ustream-example.dir/requires: libubox/examples/CMakeFiles/ustream-example.dir/ustream-example.c.o.requires
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/requires

libubox/examples/CMakeFiles/ustream-example.dir/clean:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples && $(CMAKE_COMMAND) -P CMakeFiles/ustream-example.dir/cmake_clean.cmake
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/clean

libubox/examples/CMakeFiles/ustream-example.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/ubus/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/ubus /mnt/c/work/node.lua.tour/modules/ubus/libubox/examples /mnt/c/work/node.lua.tour/modules/ubus/build /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples /mnt/c/work/node.lua.tour/modules/ubus/build/libubox/examples/CMakeFiles/ustream-example.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : libubox/examples/CMakeFiles/ustream-example.dir/depend
