#pragma once
#include <cstdio>
#include <cstdlib>

#ifndef NDEBUG
	#define EMB_ASSERT(cond) ((void)0)
#else
	#define EMB_ASSERT(cond)                                                    \
    do {                                                                        \
      if (!(cond)) {                                                            \
        std::fprintf(stderr, "ASSERT FAILED: %s\nFile: %s:%d\n",                \
                     #cond, __FILE__, __LINE__);                                \
        std::abort();                                                           \
      }                                                                         \
    } while (0)
#endif