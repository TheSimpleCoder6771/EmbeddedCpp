# Tell CMake we're building for a non-OS "Generic" embedded target
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

# --- Toolchain executables ---
set(TOOLCHAIN_PREFIX arm-none-eabi)

set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PREFIX}-gcc)

set(CMAKE_AR      ${TOOLCHAIN_PREFIX}-ar)
set(CMAKE_OBJCOPY ${TOOLCHAIN_PREFIX}-objcopy)
set(CMAKE_OBJDUMP ${TOOLCHAIN_PREFIX}-objdump)
set(CMAKE_SIZE    ${TOOLCHAIN_PREFIX}-size)

# For bare-metal, CMake shouldn't try to run executables during "try_compile"
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Optional: produce .elf
set(CMAKE_EXECUTABLE_SUFFIX ".elf")

# --- CPU settings (override from command line if you want) ---
# Example defaults: Cortex-M4F hard-float (STM32F4 style)
set(ARM_CPU "cortex-m4" CACHE STRING "ARM CPU (e.g. cortex-m0, m3, m4, m7, r4f)")
set(ARM_FPU "fpv4-sp-d16" CACHE STRING "ARM FPU (e.g. fpv4-sp-d16, fpv5-sp-d16, none)")
set(ARM_FLOAT_ABI "hard" CACHE STRING "float ABI: soft, softfp, hard")

set(ARM_COMMON_FLAGS "-mcpu=${ARM_CPU} -mthumb")

if(NOT ARM_FPU STREQUAL "none")
  set(ARM_COMMON_FLAGS "${ARM_COMMON_FLAGS} -mfpu=${ARM_FPU} -mfloat-abi=${ARM_FLOAT_ABI}")
endif()

# --- Common embedded flags (you can tune these later) ---
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   ${ARM_COMMON_FLAGS} -ffreestanding -fno-builtin")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ARM_COMMON_FLAGS} -ffreestanding -fno-builtin -fno-exceptions -fno-rtti")

# Linker flags are usually set per-target because they depend on your linker script