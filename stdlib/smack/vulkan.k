// stdlib/smack/vulkan.k — Vulkan loader FFI (pure Krypton, macOS arm64).
//
// Raw FFI to the Homebrew Vulkan loader (/opt/homebrew/lib/libvulkan.1.dylib)
// via headers/vulkan.krh. Every Vulkan entry point takes pointers; structs
// are materialized in bufNew() arenas here. No C helpers, no Python, no JS.
//
// Struct layouts (ARM64 LP64, packed at 8-byte alignment with u32 + 4-byte pad):
//
//   VkApplicationInfo (56 bytes)
//     0  sType             u32 (VK_STRUCTURE_TYPE_APPLICATION_INFO = 0)
//     8  pNext             8B  (0)
//     16 pApplicationName  8B  (Krypton string pointer — NUL-terminated in GC arena)
//     24 applicationVersion u32 (+4B pad)
//     32 pEngineName       8B  (Krypton string pointer)
//     40 engineVersion     u32 (+4B pad)
//     48 apiVersion        u32 (+4B pad)
//
//   VkInstanceCreateInfo (64 bytes)
//     0  sType             u32 (VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1)
//     8  pNext             8B  (0)
//     16 flags             u32 (+4B pad)
//     24 pApplicationInfo  8B  (pointer to VkApplicationInfo)
//     32 enabledLayerCount u32 (+4B pad)
//     40 ppEnabledLayerNames 8B (0)
//     48 enabledExtensionCount u32 (+4B pad)
//     56 ppEnabledExtensionNames 8B (0)
//
//  apiVersion = (variant << 29) | (major << 22) | (minor << 12) | patch;
//  VK_API_VERSION_1_0 = 1 << 22 = 4194304.

module smack_vulkan

import "head:vulkan"

func VK_SUCCESS() { emit 0 }
func VK_ERROR_INCOMPATIBLE_DRIVER() { emit 0 - 9 }
func VK_API_VERSION_1_0() { emit 4194304 }
func VK_STRUCTURE_TYPE_APPLICATION_INFO() { emit 0 }
func VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO() { emit 1 }

func smackVkMajor(v) { emit toInt(v) / 4194304 }
func smackVkMinor(v) { emit (toInt(v) / 4096) % 1024 }
func smackVkPatch(v) { emit toInt(v) % 4096 }

// Probe the loader's API version (works with no ICD installed).
// Returns struct { rc, version }.
func smackVkProbe() {
    let p = bufNew(8)
    bufSetQwordAt(p, 0, 0)
    let rc = vkEnumerateInstanceVersion(p)
    let r = structNew()
    r = setField(r, "rc", toInt(rc))
    r = setField(r, "version", bufGetDwordAt(p, 0))
    emit r
}

// Create a minimal Vulkan instance. Fills a VkApplicationInfo and
// VkInstanceCreateInfo in arena memory; calls vkCreateInstance(1.0).
// Returns struct { rc, instance }.
// Byte-wise comparison of a NUL-terminated buffer string vs a Krypton string.
func _strEqBytes(buf, off, s) {
    let n = len(s)
    let i = 0
    while i < n {
        if bufGetByte(buf, off + i) != charCode(s[i]) { emit 0 }
        i += 1
    }
    if bufGetByte(buf, off + i) != 0 { emit 0 }
    emit 1
}

// Is `name` among the instance's supported extensions? Two-step enumeration:
// vkEnumerateInstanceExtensionProperties(0, count, 0) then with a buffer.
// VkExtensionProperties stride = 260 bytes (char[256] + uint32).
func smackVkHasExtension(name) {
    let p = bufNew(8)
    bufSetQwordAt(p, 0, 0)
    let rc = vkEnumerateInstanceExtensionProperties(0, p, 0)
    if rc != 0 { emit 0 }
    let cnt = bufGetDwordAt(p, 0)
    if cnt == 0 { emit 0 }
    let p2 = bufNew(8)
    bufSetQwordAt(p2, 0, cnt)
    let props = bufNew(cnt * 260)
    rc = vkEnumerateInstanceExtensionProperties(0, p2, props)
    if rc != 0 { emit 0 }
    let total = bufGetDwordAt(p2, 0)
    let i = 0
    while i < total {
        if _strEqBytes(props, i * 260, name) == 1 { emit 1 }
        i += 1
    }
    emit 0
}

// VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR
func VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR() { emit 1 }

func smackVkInstanceInit() {
    let app = bufNew(56)
    bufSetQwordAt(app, 0, VK_STRUCTURE_TYPE_APPLICATION_INFO())
    bufSetQwordAt(app, 8, 0)
    bufSetQwordAt(app, 16, "smack-probe")
    bufSetQwordAt(app, 24, 0)
    bufSetQwordAt(app, 32, "smack")
    bufSetQwordAt(app, 40, 0)
    bufSetQwordAt(app, 48, VK_API_VERSION_1_0())

    // MoltenVK is a portability driver; VK_KHR_portability_enumeration must
    // be enabled or vkCreateInstance returns VK_ERROR_INCOMPATIBLE_DRIVER.
    let usePortability = smackVkHasExtension("VK_KHR_portability_enumeration")
    let flags = 0
    let extCount = 0
    let extNamesPtr = 0
    if usePortability == 1 {
        flags = VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR()
        let extStorage = bufNew(8)
        bufSetQwordAt(extStorage, 0, "VK_KHR_portability_enumeration")
        extNamesPtr = extStorage
        extCount = 1
    }

    let info = bufNew(64)
    bufSetQwordAt(info, 0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO())
    bufSetQwordAt(info, 8, 0)
    bufSetQwordAt(info, 16, flags)
    bufSetQwordAt(info, 24, app)
    bufSetQwordAt(info, 32, 0)
    bufSetQwordAt(info, 40, 0)
    bufSetQwordAt(info, 48, extCount)
    bufSetQwordAt(info, 56, extNamesPtr)

    let pInst = bufNew(8)
    bufSetQwordAt(pInst, 0, 0)
    let rc = vkCreateInstance(info, 0, pInst)

    let r = structNew()
    r = setField(r, "rc", toInt(rc))
    r = setField(r, "instance", bufGetQwordAt(pInst, 0))
    emit r
}

// Destroy an instance created by smackVkInstanceInit. rc is ignored.
func smackVkInstanceDestroy(handle) {
    if toInt(handle) == 0 { emit 0 }
    vkDestroyInstance(handle, 0)
    emit 1
}

// Enumerate physical devices. Returns struct { rc, count, devices }.
// `devices` is the raw buffer of VkPhysicalDevice handles (8 bytes each),
// indexable via bufGetQwordAt(devices, i * 8).
func smackVkDeviceList(instance, maxDevices) {
    let p = bufNew(8)
    bufSetQwordAt(p, 0, toInt(maxDevices))
    let devices = bufNew(8 * toInt(maxDevices))
    let rc = vkEnumeratePhysicalDevices(instance, p, devices)
    let r = structNew()
    r = setField(r, "rc", toInt(rc))
    r = setField(r, "count", bufGetDwordAt(p, 0))
    r = setField(r, "devices", devices)
    emit r
}

// Query core properties of a physical device into an 824-byte buffer.
// Returns the buffer pointer (caller reads deviceType/deviceName/... at known
// offsets; see docs for the VkPhysicalDeviceProperties layout).
func smackVkDeviceProperties(physicalDevice) {
    let props = bufNew(824)
    vkGetPhysicalDeviceProperties(physicalDevice, props)
    emit props
}

// VkPhysicalDeviceProperties: deviceName is char[256] at offset 20.
// Rebuild the Krypton string from raw bytes (NUL-terminated).
func smackVkDeviceName(props) {
    let sb = sbNew()
    let i = 0
    while i < 256 {
        let b = bufGetByte(props, 20 + i)
        if b == 0 { break }
        sb = sbAppend(sb, fromCharCode(b))
        i += 1
    }
    emit sbToString(sb)
}
// Human-readable deviceType (offset 16, u32).
func smackVkDeviceTypeName(props) {
    let t = bufGetDwordAt(props, 16)
    if t == 1 { emit "discrete" }
    if t == 2 { emit "integrated" }
    if t == 3 { emit "virtual" }
    if t == 4 { emit "cpu" }
    emit "unknown"
}
