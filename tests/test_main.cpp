#include <cstdio>
#include "assert.hpp"

static int run_tests()
{
    EMB_ASSERT(2 * 3 == 6);
    EMB_ASSERT((10 - 7) == 3);
    return 0;
}

int main()
{
    std::puts("Running tests...");
    int rc = run_tests();
    std::puts("All tests passed.");
    return rc;
}