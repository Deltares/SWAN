/* Return committed process bytes on Windows or resident bytes on Linux. */
#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#elif defined(__linux__)
#include <stdio.h>
#include <unistd.h>
#endif

int64_t swan_test_process_bytes(void)
{
#if defined(_WIN32)
    PROCESS_MEMORY_COUNTERS_EX counters;
    counters.cb = sizeof(counters);
    if (!GetProcessMemoryInfo(GetCurrentProcess(),
                             (PROCESS_MEMORY_COUNTERS *)&counters,
                             sizeof(counters))) {
        return -1;
    }
    return (int64_t)counters.PrivateUsage;
#elif defined(__linux__)
    unsigned long pages_total;
    unsigned long pages_resident;
    long page_size = sysconf(_SC_PAGESIZE);
    FILE *stream = fopen("/proc/self/statm", "r");
    if (stream == NULL) {
        return -1;
    }
    int fields = fscanf(stream, "%lu %lu", &pages_total, &pages_resident);
    fclose(stream);
    if (fields != 2 || page_size <= 0) {
        return -1;
    }
    return (int64_t)pages_resident * page_size;
#else
    return -1;
#endif
}
