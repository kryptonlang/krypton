// Vulkan loader probe (macOS arm64): link + vkEnumerateInstanceVersion +
// vkCreateInstance. MoltenVK must be installed for the instance create
// (brew install molten-vk); the version probe works without it.
// PASS criteria: version probe rc == 0 and rc is 0 or VK_ERROR_INCOMPATIBLE_DRIVER.
import "k:smack/vulkan"

func check(name, cond) {
    if cond {
        print("[PASS] " + name)
    } else {
        print("[FAIL] " + name)
        exit("1")
    }
    emit 0
}

just run {
    print("Vulkan probe")

    // ── version probe (no ICD needed) ───────────────────────────
    let probe = smackVkProbe()
    let prc = getField(probe, "rc")
    let version = getField(probe, "version")
    check("vkEnumerateInstanceVersion rc", prc == 0)
    print("vulkan loader API: " + smackVkMajor(version) + "." + smackVkMinor(version) + "." + smackVkPatch(version))

    // ── instance create via MoltenVK ────────────────────────────
    let r = smackVkInstanceInit()
    let rc = getField(r, "rc")
    let instance = getField(r, "instance")
    print("vkCreateInstance rc=" + rc)
    if rc == VK_ERROR_INCOMPATIBLE_DRIVER() {
        print("vkCreateInstance: VK_ERROR_INCOMPATIBLE_DRIVER (no ICD; loader-only path OK)")
        print("[PASS] vulkan probe (loader-only)")
        exit("0")
    }
    check("vkCreateInstance rc", rc == VK_SUCCESS())
    check("vkCreateInstance returned handle", instance != 0)

    // ── physical devices ─────────────────────────────────────────
    let dl = smackVkDeviceList(instance, 4)
    check("vkEnumeratePhysicalDevices rc", getField(dl, "rc") == 0)
    let count = getField(dl, "count")
    print("physical devices: " + count)
    check("at least one device", count >= 1)
    let devices = getField(dl, "devices")
    let i = 0
    while i < count {
        let dev = bufGetQwordAt(devices, i * 8)
        let props = smackVkDeviceProperties(dev)
        print("device " + i + ": " + smackVkDeviceName(props) + " (" + smackVkDeviceTypeName(props) + ")")
        i += 1
    }

    smackVkInstanceDestroy(instance)
    print("[PASS] vulkan probe")
}
