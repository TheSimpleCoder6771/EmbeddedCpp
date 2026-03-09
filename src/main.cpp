#include <cstdint>
#include <cstdio>
#include "assert.hpp"


static void print_type_sizes()
{
    std::printf("sizeof(uint8_t)  = %zu\n", sizeof(std::uint8_t));
    std::printf("sizeof(uint16_t) = %zu\n", sizeof(std::uint16_t));
    std::printf("sizeof(uint32_t) = %zu\n", sizeof(std::uint32_t));
    std::printf("sizeof(size_t)   = %zu\n", sizeof(std::size_t));
}

int main()
{
    std::puts("Day 1: Embedded C++ skeleton build OK.");
    print_type_sizes();

    // A couple of sanity checks
    static_assert(sizeof(std::uint32_t) == 4, "uint32_t is not 4 bytes?");
    EMB_ASSERT(1 + 1 == 2);

    return 0;
}