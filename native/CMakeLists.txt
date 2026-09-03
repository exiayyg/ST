cmake_minimum_required(VERSION 3.21)

project(singular_tower_native VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(GODOTCPP_API_VERSION "4.7" CACHE STRING "Godot API version targeted by godot-cpp")
set(GODOTCPP_TARGET "template_debug" CACHE STRING "Godot build target")
set(GODOTCPP_USE_HOT_RELOAD ON CACHE BOOL "Enable GDExtension hot reload support")
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp.profile.json" CACHE FILEPATH
    "Compile only the Godot classes used by this extension")

add_subdirectory(third_party/godot-cpp)

add_library(momentum_core STATIC
    src/core/momentum_world.cpp
)
target_include_directories(momentum_core PUBLIC src)
target_compile_features(momentum_core PUBLIC cxx_std_17)

add_library(singular_tower_native SHARED
    src/godot/momentum_simulation.cpp
    src/godot/register_types.cpp
)
# register_class<T>() instantiates the native object allocator in this translation
# unit, so a stale object file after a class-layout change corrupts the heap.
# Keep these dependencies explicit even when localized MSVC /showIncludes output
# prevents Ninja from discovering the transitive headers reliably.
set_source_files_properties(src/godot/register_types.cpp PROPERTIES OBJECT_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/godot/momentum_simulation.hpp;${CMAKE_CURRENT_SOURCE_DIR}/src/core/momentum_world.hpp"
)
target_include_directories(singular_tower_native PRIVATE src)
target_link_libraries(singular_tower_native PRIVATE momentum_core godot::cpp)

get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)
set(SINGULAR_TOWER_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../addons/singular_tower/bin")
set_target_properties(singular_tower_native PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
    POSITION_INDEPENDENT_CODE ON
    PREFIX "lib"
    OUTPUT_NAME "singular_tower${GODOTCPP_SUFFIX}"
    LIBRARY_OUTPUT_DIRECTORY "$<1:${SINGULAR_TOWER_OUTPUT_DIR}>"
    RUNTIME_OUTPUT_DIRECTORY "$<1:${SINGULAR_TOWER_OUTPUT_DIR}>"
    PDB_OUTPUT_DIRECTORY "$<1:${SINGULAR_TOWER_OUTPUT_DIR}>"
)

include(CTest)
if(BUILD_TESTING)
    add_executable(momentum_core_tests tests/momentum_world_tests.cpp)
    target_link_libraries(momentum_core_tests PRIVATE momentum_core)
    add_test(NAME momentum_core_tests COMMAND momentum_core_tests)

    add_executable(momentum_core_benchmark tests/momentum_world_benchmark.cpp)
    target_link_libraries(momentum_core_benchmark PRIVATE momentum_core)
endif()
