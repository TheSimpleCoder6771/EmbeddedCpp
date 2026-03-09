cmake_minimum_required(VERSION 3.20)
project(embedded_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(app src/main.cpp)
target_include_directories(app PRIVATE include)

add_executable(tests tests/test_main.cpp)
target_include_directories(tests PRIVATE include)

# Strict warnings + embedded-style restrictions (where supported)
if (MSVC)
    target_compile_options(app PRIVATE /W4 /WX)
    target_compile_options(tests PRIVATE /W4 /WX)
else()
    target_compile_options(app PRIVATE -Wall -Wextra -Wpedantic -Werror -fno-exceptions -fno-rtti)
    target_compile_options(tests PRIVATE -Wall -Wextra -Wpedantic -Werror -fno-exceptions -fno-rtti)
endif()