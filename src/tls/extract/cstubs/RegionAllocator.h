#ifndef HEADER_REGIONALLOCATOR_H
#define HEADER_REGIONALLOCATOR_H

/******
This file has multiple compilation options:
1.  Choice of region-based heap:
    - USE_HEAP_REGIONS - use region-based heaps in usermode.  On Windows, this
      leverages a separate heap instance per region, via CreateHeap().  On Linux,
      this manages a per-region linked-list of allocations made via malloc().
    - USE_KERNEL_REGIONS - Windows only.  Manage a per-region linked list of
      allocations made via ExAllocatePoolWithTag().
    - default... no-op.  All allocations are made without region tracking.
    
2.  REGION_STATISTICS.  If set, for both USE_HEAP_REGIONS and USE_KERNEL_REGIONS,
    then the allocator maintains per-region statistics, for total bytes
    allocated, peak bytes, count of allocations, etc.

******/


typedef void *HEAP_REGION;

// Perform per-process initialization
// returns 0 for error, nonzero for success
int HeapRegionInitialize(void);

// Perform per-process termination
void HeapRegionCleanup(void);

void PrintHeapRegionStatistics(HEAP_REGION rgn);

// KRML_HOST_MALLOC/CALLOC/FREE plug-ins
void* HeapRegionMalloc(size_t cb);
void* HeapRegionCalloc(size_t num, size_t size);
void HeapRegionFree(void* pv);

#if USE_HEAP_REGIONS

// Use a per-region heap.  All unfreed allocations within the region will
// be freed when the region is destroyed.  A default region holds allocations
// made outside of ENTER/LEAVE.  It will be freed when the region allocator
// is cleaned up.
#if IS_WINDOWS
  #define ENTER_HEAP_REGION(rgn) HeapRegionEnter(rgn)
  #define LEAVE_HEAP_REGION()    HeapRegionLeave()
  #define CREATE_HEAP_REGION(prgn)   HeapRegionCreateAndRegister(prgn)
  #define VALID_HEAP_REGION(rgn)    ((rgn) != NULL)
  #define DESTROY_HEAP_REGION(rgn) HeapRegionDestroy(rgn)
#else
  #define ENTER_HEAP_REGION(rgn) HeapRegionEnter(rgn)
  #define LEAVE_HEAP_REGION()    HeapRegionLeave()
  #define CREATE_HEAP_REGION(prgn)   HeapRegionCreateAndRegister(prgn)
  #define VALID_HEAP_REGION(rgn)    ((rgn) != NULL)
  #define DESTROY_HEAP_REGION(rgn) HeapRegionDestroy(rgn)
#endif
void HeapRegionEnter(HEAP_REGION rgn);
void HeapRegionLeave(void);
void HeapRegionCreateAndRegister(HEAP_REGION *prgn);
void HeapRegionDestroy(HEAP_REGION rgn);

#elif USE_KERNEL_REGIONS
// Use regions managed within the kernel pool.  All unfreed allocations within
// the region will be freed when the region is destroyed.  A deafult region
// holds allocations made outside of ENTER/LEAVE.  It will be freed when
// the region allocator is cleaned up.
#if IS_WINDOWS
  typedef struct {
    LIST_ENTRY entry; // dlist of region_entry
    PETHREAD id;
    void *region;     // ptr to dlist of actual pool allocations
  } region_entry;

  #define ENTER_HEAP_REGION(rgn) \
    region_entry e; \
    HeapRegionRegister(&e, (rgn));
    
  #define LEAVE_HEAP_REGION() \
    HeapRegionUnregister(&e);
    
  #define CREATE_HEAP_REGION(prgn) \
    region_entry e; \
    HeapRegionCreateAndRegister(&e, (prgn));

  #define VALID_HEAP_REGION(rgn)    ((rgn) != NULL)
    
  #define DESTROY_HEAP_REGION(rgn) HeapRegionDestroy(rgn)
  
  void HeapRegionCreateAndRegister(HEAP_REGION *prgn);
  void HeapRegionRegister(region_entry* pe, HEAP_REGION rgn);
  void HeapRegionUnregister(region_entry* pe);
  void HeapRegionDestroy(HEAP_REGION rgn);
#else
  #error Non-Windows support is NYY
#endif

#else
// Use the single process-wide heap.  All unfreed allocations will be leaked.

#define ENTER_HEAP_REGION(rgn)
#define LEAVE_HEAP_REGION()
#define CREATE_HEAP_REGION(prgn) *(prgn)=NULL
#define VALID_HEAP_REGION(rgn) TRUE
#define DESTROY_HEAP_REGION(rgn)

#endif

#endif // HEADER_REGIONALLOCATOR_H
