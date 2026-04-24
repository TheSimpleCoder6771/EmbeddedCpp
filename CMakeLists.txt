cmake_minimum_required(VERSION 3.20)
project(app LANGUAGES C CXX ASM)

# ------------------------------------------------------------
# Detect embedded vs host
# ------------------------------------------------------------
set(IS_EMBEDDED OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "Generic" OR CMAKE_CROSSCOMPILING)
  set(IS_EMBEDDED ON)
endif()

# ------------------------------------------------------------
# Standards
# ------------------------------------------------------------
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# cmake -S . -B build-host -G Ninja -DCMAKE_BUILD_TYPE=Debug
# cmake --build build-host

# cmake -S . -B build-wb-cm4 -G Ninja \
#   -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/arm-none-eabi-gcc.cmake \
#   -DWB_CORE=CM4 \
#   -DSTM32_CHIP=STM32WB55xx \
#   -DSTARTUP_FILE=startup/startup_stm32wb55xx_cm4.s \
#   -DLINKER_SCRIPT=linkerfile/STM32WB55xx_FLASH.ld \
#   -DCMAKE_BUILD_TYPE=Debug

# cmake --build build-wb-cm4

# cmake -S . -B build-wb-cm0p -G Ninja \
#   -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/arm-none-eabi-gcc.cmake \
#   -DWB_CORE=CM0PLUS \
#   -DSTM32_CHIP=STM32WB55xx \
#   -DSTARTUP_FILE=startup/startup_stm32wb55xx_cm0plus.s \
#   -DLINKER_SCRIPT=linkerfile/STM32WB55xx_CM0PLUS_FLASH.ld \
#   -DCMAKE_BUILD_TYPE=Debug

# cmake --build build-wb-cm0p


# ------------------------------------------------------------
# User-configurable inputs (mostly for embedded build)
# ------------------------------------------------------------
# Typical usage:
#   -DLINKER_SCRIPT=linkerfile/STM32WB55xx_FLASH.ld
#   -DSTARTUP_FILE=startup/startup_stm32wb55xx_cm4.s
set(LINKER_SCRIPT "" CACHE FILEPATH "Path to .ld (required for embedded)")
set(STARTUP_FILE  "" CACHE FILEPATH "Path to startup .s/.S (required for embedded)")

# STM32 device macro for WB55 family
set(STM32_CHIP "STM32WB55xx" CACHE STRING "STM32 device macro (default: STM32WB55xx)")

# Which core are you building for? (Most apps build CM4)
set(WB_CORE "CM4" CACHE STRING "Target core: CM4 or CM0PLUS")

# Name of your output (host: <FW_NAME>, embedded: <FW_NAME>_<WB_CORE>.elf)
set(FW_NAME "app" CACHE STRING "Base name for output binaries")

# Drivers often don't compile on host (CMSIS/register access). Default: ON embedded, OFF host.
set(DEFAULT_DRIVERS OFF)
if(IS_EMBEDDED)
  set(DEFAULT_DRIVERS ON)
endif()
option(ENABLE_DRIVERS "Build driver/src (hardware drivers)" ${DEFAULT_DRIVERS})

# Prefer putting CPU flags in the TOOLCHAIN FILE. Enable this only if your toolchain file doesn't set them.
option(ADD_CPU_FLAGS_HERE "Add CPU/FPU flags from this CMakeLists (otherwise rely on toolchain file)" OFF)

# Cortex flags for STM32WB:
# - CM4 has FPU (single-precision)
# - CM0PLUS has no FPU
set(MCPU_FLAGS_CM4    "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
set(MCPU_FLAGS_CM0P   "-mcpu=cortex-m0plus -mthumb")

# ------------------------------------------------------------
# Helper: warnings
# ------------------------------------------------------------
function(apply_warnings tgt)
  if(MSVC)
    target_compile_options(${tgt} PRIVATE /W4 /WX)
  else()
    target_compile_options(${tgt} PRIVATE -Wall -Wextra -Wpedantic -Werror)
  endif()
endfunction()

# ------------------------------------------------------------
# Pick entry file:
#   Host prefers src/main_host.(c|cpp) if present
#   Embedded prefers src/main_mcu.(c|cpp) if present
#   Falls back to src/main.(c|cpp)
# ------------------------------------------------------------
set(APP_ENTRY "")

if(IS_EMBEDDED)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/main_mcu.cpp")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main_mcu.cpp")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main_mcu.c")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main_mcu.c")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main.cpp")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main.cpp")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main.c")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main.c")
  endif()
else()
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/main_host.cpp")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main_host.cpp")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main_host.c")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main_host.c")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main.cpp")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main.cpp")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/src/main.c")
    set(APP_ENTRY "${CMAKE_SOURCE_DIR}/src/main.c")
  endif()
endif()

if(NOT APP_ENTRY)
  message(FATAL_ERROR "No entry file found. Create src/main.cpp (or main.c). Optional: main_host.*, main_mcu.*")
endif()

# ------------------------------------------------------------
# Collect sources
# NOTE: For safety-critical projects, explicit source lists are better than GLOB.
# ------------------------------------------------------------
file(GLOB_RECURSE CORE_SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/*.c"
  "${CMAKE_SOURCE_DIR}/src/*.cpp"
)

# Exclude all possible mains from the core library to avoid double compilation
list(FILTER CORE_SOURCES EXCLUDE REGEX ".*/main(_host|_mcu)?\\.(c|cpp)$")

set(DRIVER_SOURCES "")
if(ENABLE_DRIVERS)
  file(GLOB_RECURSE DRIVER_SOURCES
    CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/driver/src/*.c"
    "${CMAKE_SOURCE_DIR}/driver/src/*.cpp"
  )
endif()

# ------------------------------------------------------------
# Core library (everything except main)
# ------------------------------------------------------------
set(CORE_ALL_SOURCES ${CORE_SOURCES} ${DRIVER_SOURCES})

if(CORE_ALL_SOURCES)
  # Normal case: core has .c/.cpp sources
  add_library(core STATIC ${CORE_ALL_SOURCES})
  target_include_directories(core PUBLIC
    "${CMAKE_SOURCE_DIR}/inc"
    "${CMAKE_SOURCE_DIR}/driver/inc"
  )
  apply_warnings(core)

  # Embedded-oriented compile flags (only when embedded)
  if(NOT MSVC)
    target_compile_options(core PRIVATE
      $<$<BOOL:${IS_EMBEDDED}>:-ffunction-sections>
      $<$<BOOL:${IS_EMBEDDED}>:-fdata-sections>
      $<$<BOOL:${IS_EMBEDDED}>:-ffreestanding>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-builtin>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-exceptions>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-rtti>
    )
  endif()

  if(IS_EMBEDDED AND STM32_CHIP)
    target_compile_definitions(core PUBLIC ${STM32_CHIP})
  endif()

else()
  # Edge case: only main exists (or everything got filtered out)
  # Make core an INTERFACE library so you can still propagate includes/defs/flags.
  add_library(core INTERFACE)
  target_include_directories(core INTERFACE
    "${CMAKE_SOURCE_DIR}/inc"
    "${CMAKE_SOURCE_DIR}/driver/inc"
  )

  if(NOT MSVC)
    target_compile_options(core INTERFACE
      $<$<BOOL:${IS_EMBEDDED}>:-ffunction-sections>
      $<$<BOOL:${IS_EMBEDDED}>:-fdata-sections>
      $<$<BOOL:${IS_EMBEDDED}>:-ffreestanding>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-builtin>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-exceptions>
      $<$<BOOL:${IS_EMBEDDED}>:-fno-rtti>
    )
  endif()

  if(IS_EMBEDDED AND STM32_CHIP)
    target_compile_definitions(core INTERFACE ${STM32_CHIP})
  endif()
endif()

# Optional core macro (some codebases use these)
if(IS_EMBEDDED)
  if(WB_CORE STREQUAL "CM4")
    target_compile_definitions(core PUBLIC CORE_CM4)
  elseif(WB_CORE STREQUAL "CM0PLUS")
    target_compile_definitions(core PUBLIC CORE_CM0PLUS)
  else()
    message(FATAL_ERROR "WB_CORE must be CM4 or CM0PLUS")
  endif()
endif()

# Optional CPU flags here (prefer toolchain file instead)
if(IS_EMBEDDED AND ADD_CPU_FLAGS_HERE AND NOT MSVC)
  if(WB_CORE STREQUAL "CM4")
    target_compile_options(core PRIVATE ${MCPU_FLAGS_CM4})
  else()
    target_compile_options(core PRIVATE ${MCPU_FLAGS_CM0P})
  endif()
endif()

# ------------------------------------------------------------
# Executable target (must always have at least one source: APP_ENTRY)
# Host:    <FW_NAME>
# Embedded:<FW_NAME>_<WB_CORE>.elf
# ------------------------------------------------------------
if(IS_EMBEDDED)
  set(EXE_NAME "${FW_NAME}_${WB_CORE}.elf")
else()
  set(EXE_NAME "${FW_NAME}")
endif()

# Startup only for embedded
set(STARTUP_ABS "")
if(IS_EMBEDDED)
  if(NOT STARTUP_FILE)
    message(FATAL_ERROR "Embedded build detected but STARTUP_FILE not set. Use -DSTARTUP_FILE=startup/<file>.s")
  endif()
  set(STARTUP_ABS "${CMAKE_SOURCE_DIR}/${STARTUP_FILE}")
  if(NOT EXISTS "${STARTUP_ABS}")
    message(FATAL_ERROR "STARTUP_FILE not found: ${STARTUP_FILE}")
  endif()
endif()

add_executable(${EXE_NAME}
  ${APP_ENTRY}
  $<$<BOOL:${IS_EMBEDDED}>:${STARTUP_ABS}>
)

target_link_libraries(${EXE_NAME} PRIVATE core)
apply_warnings(${EXE_NAME})

# Optional CPU flags for link stage too
if(IS_EMBEDDED AND ADD_CPU_FLAGS_HERE AND NOT MSVC)
  if(WB_CORE STREQUAL "CM4")
    target_link_options(${EXE_NAME} PRIVATE ${MCPU_FLAGS_CM4})
  else()
    target_link_options(${EXE_NAME} PRIVATE ${MCPU_FLAGS_CM0P})
  endif()
endif()

# ------------------------------------------------------------
# Embedded link + post-build artifacts (.hex/.bin + size)
# ------------------------------------------------------------
if(IS_EMBEDDED)
  if(NOT LINKER_SCRIPT)
    message(FATAL_ERROR "Embedded build detected but LINKER_SCRIPT not set. Use -DLINKER_SCRIPT=linkerfile/<file>.ld")
  endif()

  set(LD_ABS "${CMAKE_SOURCE_DIR}/${LINKER_SCRIPT}")
  if(NOT EXISTS "${LD_ABS}")
    message(FATAL_ERROR "LINKER_SCRIPT not found: ${LINKER_SCRIPT}")
  endif()

  if(NOT MSVC)
    target_link_options(${EXE_NAME} PRIVATE
      -T${LD_ABS}
      -Wl,-Map=${CMAKE_BINARY_DIR}/${FW_NAME}_${WB_CORE}.map
      -Wl,--gc-sections
      --specs=nano.specs
      --specs=nosys.specs
    )
  endif()

  # Toolchain-provided tools if available
  if(DEFINED CMAKE_SIZE)
    set(SIZE_TOOL ${CMAKE_SIZE})
  else()
    set(SIZE_TOOL arm-none-eabi-size)
  endif()

  if(DEFINED CMAKE_OBJCOPY)
    set(OBJCOPY_TOOL ${CMAKE_OBJCOPY})
  else()
    set(OBJCOPY_TOOL arm-none-eabi-objcopy)
  endif()

  add_custom_command(TARGET ${EXE_NAME} POST_BUILD
    COMMAND ${SIZE_TOOL} $<TARGET_FILE:${EXE_NAME}>
    COMMAND ${OBJCOPY_TOOL} -O ihex   $<TARGET_FILE:${EXE_NAME}> ${CMAKE_BINARY_DIR}/${FW_NAME}_${WB_CORE}.hex
    COMMAND ${OBJCOPY_TOOL} -O binary $<TARGET_FILE:${EXE_NAME}> ${CMAKE_BINARY_DIR}/${FW_NAME}_${WB_CORE}.bin
    COMMENT "Generating .hex/.bin and printing size"
    VERBATIM
  )
endif()