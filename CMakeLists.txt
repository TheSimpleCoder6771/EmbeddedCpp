cmake_minimum_required(VERSION 3.20)
project(stm32wb55_app LANGUAGES C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---- Chip + startup + linker (edit defaults if your filenames differ) ----
set(STM32_CHIP "STM32WB55xx" CACHE STRING "STM32 device macro")
set(STARTUP_FILE "startup/startup_stm32wb55cgux.s" CACHE FILEPATH "Startup .s/.S file")
set(LINKER_SCRIPT "linkerfile/STM32WB55CGUX_FLASH.ld" CACHE FILEPATH "Linker .ld file")

# ---- IMPORTANT: CPU flags as a LIST (NOT one quoted string) ----
set(MCPU_FLAGS
  -mcpu=cortex-m4
  -mthumb
  -mfpu=fpv4-sp-d16
  -mfloat-abi=hard
)

# ---- Resolve startup/linker to absolute paths ----
set(STARTUP_ABS "${CMAKE_SOURCE_DIR}/${STARTUP_FILE}")
set(LD_ABS      "${CMAKE_SOURCE_DIR}/${LINKER_SCRIPT}")

if(NOT EXISTS "${STARTUP_ABS}")
  message(FATAL_ERROR "Startup file not found: ${STARTUP_FILE}")
endif()
if(NOT EXISTS "${LD_ABS}")
  message(FATAL_ERROR "Linker script not found: ${LINKER_SCRIPT}")
endif()

# ---- Sources (you copied CubeWB content into src/ and driver/src/) ----
file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/*.c"
  "${CMAKE_SOURCE_DIR}/src/*.cpp"
)

file(GLOB_RECURSE DRIVER_SOURCES CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/driver/src/*.c"
  "${CMAKE_SOURCE_DIR}/driver/src/*.cpp"
)

# Optional: drop template sources if present
list(FILTER DRIVER_SOURCES EXCLUDE REGEX ".*_template\\.c$")

add_executable(app.elf
  ${APP_SOURCES}
  ${DRIVER_SOURCES}
  ${STARTUP_ABS}
)

# ---- Include dirs ----
# Since you confirmed stm32wbxx_hal.h is in driver/inc, this is REQUIRED:
target_include_directories(app.elf PRIVATE
  "${CMAKE_SOURCE_DIR}/inc"
  "${CMAKE_SOURCE_DIR}/driver/inc"
  "${CMAKE_SOURCE_DIR}"
)

# Add common CubeWB-style include folders (safe even if some don't exist)
target_include_directories(app.elf PRIVATE
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/CMSIS/Include"
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/CMSIS/Device/ST/STM32WBxx/Include"
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/STM32WBxx_HAL_Driver/Inc"
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/STM32WBxx_HAL_Driver/Inc/Legacy"
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/BSP"
  "${CMAKE_SOURCE_DIR}/driver/inc/Drivers/BSP/Components/Common"
)

# ---- Defines ----
target_compile_definitions(app.elf PRIVATE
  USE_HAL_DRIVER
  ${STM32_CHIP}
)

# ---- Compile options ----
target_compile_options(app.elf PRIVATE
  ${MCPU_FLAGS}
  -Wall -Wextra -Wpedantic
  -ffunction-sections -fdata-sections
  -ffreestanding -fno-builtin
  $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>
  $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
)

# ---- Link options ----
target_link_options(app.elf PRIVATE
  ${MCPU_FLAGS}
  -T${LD_ABS}
  -Wl,-Map=${CMAKE_BINARY_DIR}/app.map
  -Wl,--gc-sections
  --specs=nano.specs
  --specs=nosys.specs
)

# ---- Post-build artifacts ----
add_custom_command(TARGET app.elf POST_BUILD
  COMMAND arm-none-eabi-size $<TARGET_FILE:app.elf>
  COMMAND arm-none-eabi-objcopy -O ihex   $<TARGET_FILE:app.elf> ${CMAKE_BINARY_DIR}/app.hex
  COMMAND arm-none-eabi-objcopy -O binary $<TARGET_FILE:app.elf> ${CMAKE_BINARY_DIR}/app.bin
  COMMENT "Generating app.hex/app.bin"
  VERBATIM
)