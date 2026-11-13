// stdlib/smack/vulkan_bridge.k — SmackSurface -> Vulkan staging bridge (pure Krypton).
//
// Allocates a host-visible, host-coherent Vulkan staging buffer, maps it, and
// exposes its raw pointer so SmackSurface pixels can be uploaded byte-for-byte
// or word-for-word directly into GPU-accessible memory. No C helpers.
//
// Struct layouts (ARM64 LP64, u32 + 4B pad):
//
//   VkBufferCreateInfo (56 bytes)
//     0  sType             u32 (VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12)
//     8  pNext             (0)
//     16 flags             u32 (+pad)
//     24 size              u64
//     32 usage             u32 (+pad)
//     36 sharingMode       u32 (+pad)
//     40 queueFamilyIndexCount u32 (+pad)
//     48 pQueueFamilyIndices   (0)
//
//   VkMemoryRequirements (24 bytes)
//     0  size              u64
//     8  alignment         u64
//     16 memoryTypeBits    u32 (+pad)
//
//   VkPhysicalDeviceMemoryProperties (520 bytes)
//     0  memoryTypeCount   u32
//     4  memoryTypes[32]   { propertyFlags u32, heapIndex u32 }  (8B each)
//     260 memoryHeapCount  u32
//     264 memoryHeaps[16]  { size u64, flags u32 }  (16B each)
//
//   VkMemoryAllocateInfo (32 bytes)
//     0  sType             u32 (VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5)
//     8  pNext             (0)
//     16 allocationSize    u64
//     24 memoryTypeIndex   u32 (+pad)
//
//   VkBufferImageCopy (56 bytes)
//     0  bufferOffset      u64
//     8  bufferRowLength   u32
//     12 bufferImageHeight u32
//     16 imageSubresource  { aspectMask u32, mipLevel u32, baseArrayLayer u32, layerCount u32 } (16B)
//     32 imageOffset       { x u32, y u32, z u32 }  (12B)
//     44 imageExtent       { width u32, height u32, depth u32 } (12B)

module smack_vulkan_bridge

import "head:vulkan"
import "k:smack/vulkan"

func VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO() { emit 12 }
func VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO() { emit 5 }
func VK_BUFFER_USAGE_TRANSFER_SRC_BIT() { emit 1 }
func VK_SHARING_MODE_EXCLUSIVE() { emit 0 }
func VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT() { emit 1 }
func VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT() { emit 2 }
func VK_MEMORY_PROPERTY_HOST_COHERENT_BIT() { emit 4 }
func VK_MEMORY_PROPERTY_HOST_CACHED_BIT() { emit 8 }
func VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL() { emit 7 }
func _pow2(n) {
    let r = 1
    let i = 0
    let cnt = toInt(n)
    while i < cnt {
        r = r * 2
        i += 1
    }
    emit r
}
func VK_IMAGE_ASPECT_COLOR_BIT() { emit 1 }
func VK_ACCESS_TRANSFER_WRITE_BIT() { emit 4096 }
func VK_ACCESS_MEMORY_READ_BIT() { emit 32768 }
func VK_PIPELINE_STAGE_TRANSFER_BIT() { emit 4096 }

// Find a host-visible, host-coherent memory type index satisfying
// `requirementsMemoryTypeBits`. Returns the type index, or 0 - 1 on failure.
func smackVkFindHostCoherentType(physicalDevice, requirementsMemoryTypeBits) {
    let want = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT() + VK_MEMORY_PROPERTY_HOST_COHERENT_BIT()
    let props = bufNew(520)
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, props)
    let memoryTypeCount = bufGetDwordAt(props, 0)
    let i = 0
    while i < memoryTypeCount {
        let bit = _pow2(i)
        if bitAnd(requirementsMemoryTypeBits, bit) != 0 {
            let flags = bufGetDwordAt(props, 4 + i * 8)
            if bitAnd(flags, want) == want {
                emit i
            }
        }
        i += 1
    }
    emit 0 - 1
}

// Allocate a host-visible, host-coherent staging buffer of `size` bytes.
// Returns struct { rc, buffer, memory } on success, or { rc } on failure.
func smackVkStagingCreate(device, physicalDevice, size) {
    let bci = bufNew(56)
    bufSetQwordAt(bci, 0, VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO())
    bufSetQwordAt(bci, 8, 0)
    bufSetQwordAt(bci, 16, 0)          // flags
    bufSetQwordAt(bci, 24, toInt(size)) // size (u64)
    bufSetQwordAt(bci, 32, VK_BUFFER_USAGE_TRANSFER_SRC_BIT())
    bufSetByte(bci, 36, VK_SHARING_MODE_EXCLUSIVE())
    bufSetByte(bci, 37, 0)
    bufSetByte(bci, 38, 0)
    bufSetByte(bci, 39, 0)
    bufSetByte(bci, 40, 0)             // queueFamilyIndexCount
    bufSetByte(bci, 41, 0)
    bufSetByte(bci, 42, 0)
    bufSetByte(bci, 43, 0)
    bufSetQwordAt(bci, 48, 0)          // queueFamilyIndices

    let pBuf = bufNew(8)
    bufSetQwordAt(pBuf, 0, 0)
    let rc = vkCreateBuffer(device, bci, 0, pBuf)
    if rc != 0 {
        let r = structNew()
        r = setField(r, "rc", toInt(rc))
        emit r
    }
    let buffer = bufGetQwordAt(pBuf, 0)

    // Memory requirements
    let reqs = bufNew(24)
    vkGetBufferMemoryRequirements(device, buffer, reqs)
    let memTypeBits = bufGetDwordAt(reqs, 16)
    let memSize = bufGetQwordAt(reqs, 0)

    let memTypeIndex = smackVkFindHostCoherentType(physicalDevice, memTypeBits)
    if memTypeIndex == 0 - 1 {
        vkDestroyBuffer(device, buffer, 0)
        let r = structNew()
        r = setField(r, "rc", 0 - 1)
        emit r
    }

    let alloc = bufNew(32)
    bufSetQwordAt(alloc, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO())
    bufSetQwordAt(alloc, 8, 0)
    bufSetQwordAt(alloc, 16, memSize)
    bufSetByte(alloc, 24, memTypeIndex)
    bufSetByte(alloc, 25, 0)
    bufSetByte(alloc, 26, 0)
    bufSetByte(alloc, 27, 0)

    let pMem = bufNew(8)
    bufSetQwordAt(pMem, 0, 0)
    rc = vkAllocateMemory(device, alloc, 0, pMem)
    if rc != 0 {
        vkDestroyBuffer(device, buffer, 0)
        let r = structNew()
        r = setField(r, "rc", toInt(rc))
        emit r
    }
    let memory = bufGetQwordAt(pMem, 0)

    rc = vkBindBufferMemory(device, buffer, memory, 0)
    if rc != 0 {
        vkFreeMemory(device, memory, 0)
        vkDestroyBuffer(device, buffer, 0)
        let r = structNew()
        r = setField(r, "rc", toInt(rc))
        emit r
    }

    let r = structNew()
    r = setField(r, "rc", 0)
    r = setField(r, "device", device)
    r = setField(r, "buffer", buffer)
    r = setField(r, "memory", memory)
    r = setField(r, "size", memSize)
    emit r
}

// Destroy a staging buffer + memory created by smackVkStagingCreate.
func smackVkStagingDestroy(device, staging) {
    if staging == "" { emit 0 }
    let buffer = getField(staging, "buffer")
    let memory = getField(staging, "memory")
    if buffer != 0 { vkDestroyBuffer(device, buffer, 0) }
    if memory != 0 { vkFreeMemory(device, memory, 0) }
    emit 1
}

// Upload `length` bytes from `srcBuf` into the mapped staging buffer.
// Copies via qword loads/stores (fast path), tail bytes handled individually.
func smackVkStagingUpload(staging, srcBuf, length) {
    if staging == "" { emit 0 }
    let device = getField(staging, "device")
    let memory = getField(staging, "memory")
    let pLength = toInt(length)
    if pLength <= 0 { emit 0 }
    let ppData = bufNew(8)
    bufSetQwordAt(ppData, 0, 0)
    let rc = vkMapMemory(device, memory, 0, pLength, 0, ppData)
    if rc != 0 { emit toInt(rc) }
    let dst = bufGetQwordAt(ppData, 0)
    let remaining = pLength
    let off = 0
    while remaining >= 8 {
        bufSetQwordAt(dst, off, bufGetQwordAt(srcBuf, off))
        off += 8
        remaining -= 8
    }
    while remaining > 0 {
        bufSetByte(dst, off, bufGetByte(srcBuf, off))
        off += 1
        remaining -= 1
    }
    vkUnmapMemory(device, memory)
    emit 1
}
