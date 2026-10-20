// Copyright 2025 DolphiniOS Project
// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "Common/MemoryUtil.h"

#include <lwmem/lwmem.h>
#include <mach/mach.h>
#include <stdio.h>
#include <string>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>

#include "Common/CommonFuncs.h"
#include "Common/CommonTypes.h"
#include "Common/Logging/Log.h"
#include "Common/MsgHandler.h"

// 512 MiB... hopefully this is enough, because we can't allocate more if we need it
constexpr size_t EXECUTABLE_REGION_SIZE = 536870912;

static u8* g_rx_region = nullptr;
static ptrdiff_t g_rw_region_diff = 0;

// StikDebug "universal.js" calls (iOS 26, TXM/SPTM devices).
//
// The debugger script stops on `brk #0xf00d`, reads the command number from x16, skips the
// breakpoint and runs the command. x0 and x1 carry the arguments and x0 carries the result.
//   x16 = 0  detach the debugger
//   x16 = 1  prepare [x0, x0 + x1) as an executable region, returns the region in x0
// These must stay out-of-line and untouched by the optimizer so the registers line up.
extern "C" {
__attribute__((noinline, optnone, naked)) static void PrismJIT26Detach()
{
  asm volatile("mov x16, #0\n"
               "brk #0xf00d\n"
               "ret\n");
}

__attribute__((noinline, optnone, naked)) static void* PrismJIT26PrepareRegion(void* address,
                                                                                size_t length)
{
  asm volatile("mov x16, #1\n"
               "brk #0xf00d\n"
               "ret\n");
}
}

namespace Common
{
void AllocateExecutableMemoryRegion_LuckTXM()
{
  if (g_rx_region)
  {
    return;
  }

  const size_t size = EXECUTABLE_REGION_SIZE;
  void* mapping = mmap(nullptr, size, PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);

  if (mapping == MAP_FAILED || mapping == nullptr)
  {
    PanicAlertFmt("AllocateExecutableMemoryRegion failed! mmap returned {}", LastStrerrorString());
    return;
  }

  u8* rx_ptr = static_cast<u8*>(mapping);

  void* prepared = PrismJIT26PrepareRegion(rx_ptr, size);

  if (prepared != rx_ptr)
  {
    PanicAlertFmt("JIT setup failed: the debugger did not prepare the code region.\n\n"
                  "Enable JIT from StikDebug with the universal.js script, then try again.");
    munmap(rx_ptr, size);
    return;
  }

  vm_address_t rw_region = 0;
  vm_address_t target = reinterpret_cast<vm_address_t>(rx_ptr);
  vm_prot_t cur_protection = 0;
  vm_prot_t max_protection = 0;

  kern_return_t retval =
      vm_remap(mach_task_self(), &rw_region, size, 0, true, mach_task_self(), target, false,
               &cur_protection, &max_protection, VM_INHERIT_DEFAULT);
  if (retval != KERN_SUCCESS)
  {
    PanicAlertFmt("AllocateExecutableMemoryRegion failed! vm_map returned {0:#x}", retval);
    return;
  }

  u8* rw_ptr = reinterpret_cast<u8*>(rw_region);

  if (mprotect(rw_ptr, size, PROT_READ | PROT_WRITE) != 0)
  {
    PanicAlertFmt("AllocateExecutableMemoryRegion failed! mprotect returned {}", LastStrerrorString());
    return;
  }

  lwmem_region_t regions[] =
  {
    { (void*)rw_ptr, size },
    { NULL, 0 }
  };

  size_t lwret = lwmem_assignmem(regions);
  if (lwret == 0)
  {
    PanicAlertFmt("AllocateExecutableMemoryRegion failed!\nlwmem_assignmem failed");
    return;
  }

  g_rx_region = rx_ptr;
  g_rw_region_diff = rw_ptr - rx_ptr;

  // Everything the JIT will ever execute lives in this one region, so the debugger is no longer
  // needed. Detaching also keeps fastmem faults from bouncing through the debug connection.
  PrismJIT26Detach();
}

ptrdiff_t AllocateWritableRegionAndGetDiff_LuckTXM()
{
  return g_rw_region_diff;
}

void* AllocateExecutableMemory_LuckTXM(size_t size)
{
  if (g_rx_region == nullptr)
  {
    PanicAlertFmt("AllocateExecutableMemory failed!\ng_rx_region is nullptr");
    return nullptr;
  }

  const size_t pagesize = sysconf(_SC_PAGESIZE);

  void* raw = lwmem_malloc(size + pagesize - 1 + sizeof(void*));

  if (!raw)
  {
    PanicAlertFmt("AllocateExecutableMemory failed!\nlwmem_malloc returned nullptr");
    return nullptr;
  }

  uintptr_t raw_addr = (uintptr_t)raw + sizeof(void*);
  uintptr_t aligned = (raw_addr + pagesize - 1) & ~(pagesize - 1);

  ((void**)aligned)[-1] = raw;

  return (u8*)aligned - g_rw_region_diff;
}

void FreeExecutableMemory_LuckTXM(void* ptr)
{
  lwmem_free(((void**)ptr)[-1]);
}
}  // namespace Common