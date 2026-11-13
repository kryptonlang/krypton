// examples/smack_present.k — SmackUI present: NSWindow + CAMetalLayer +
// Vulkan (MoltenVK), all in pure Krypton.
//
//   KRYPTON_ROOT=$PWD ./bootstrap/kcc_driver_macos_aarch64 examples/smack_present.k -o /tmp/smack_present
//   /tmp/smack_present
//
// Opens a 640x480 window and presents 90 frames of the SmackSurface scene
// drawn by the pure-Krypton compositor, uploaded into the swapchain via a
// host-visible staging buffer and vkCmdCopyBufferToImage. Requires MoltenVK
// (brew install molten-vk) and the Homebrew Vulkan loader. macOS arm64 only.
//
// No shaders are needed: the swapchain image is written by a buffer-to-image
// copy; layout transitions are pipeline barriers.
import "k:smack/vulkan"
import "k:smack/geometry"
import "k:smack/compositor"
import "k:smack/vulkan_bridge"
import "k:choc_macos"

// Auxiliary Vulkan helper buffers are allocated in a tiny helper frame so they
// land at the low end of Krypton's bump arena — away from the unmapped page
// reserved by the much larger __main__ frame.
func _makeAuxiliaryBuffers() {
    let barrier = bufNew(128)
    let copyRegion = bufNew(56)
    let r = structNew()
    r = setField(r, "barrier", barrier)
    r = setField(r, "copyRegion", copyRegion)
    emit r
}

func _runPresent() {

    let aux = _makeAuxiliaryBuffers()
    let barrier = getField(aux, "barrier")
    let copyRegion = getField(aux, "copyRegion")
    print("n0 window first")
    let app = chocSharedApp()
    msg_1(app, "setActivationPolicy:", 0)
    let mask = 15
    let raw = msg(cls("NSWindow"), "alloc")
    let win = msg_rect(raw, "initWithContentRect:styleMask:backing:defer:",
        0, 0, 640, 480, mask, 2, 0)
    msg_1(win, "setTitle:", nsString("SmackUI over Vulkan"))
    let cv = msg(win, "contentView")
    chocShow(win, app)
    let layer = msg(msg(cls("CAMetalLayer"), "alloc"), "init")
    msg_d2(layer, "setDrawableSize:", 640, 480)
    msg_1(cv, "setWantsLayer:", 1)
    msg_1(cv, "setLayer:", layer)
    chocFinishLaunching(app)
    print("n1 window created")
    let ir = smackVkInstanceInit()
    let instance = getField(ir, "instance")
    print("n2 instance ok")
    let dl = smackVkDeviceList(instance, 1)
    let pDevice = bufGetQwordAt(getField(dl, "devices"), 0)
    print("n3 device ok")
    // surface via CAMetalLayer
    let pSurface = bufNew(8)
    bufSetQwordAt(pSurface, 0, 0)
    let surfInfo = bufNew(32)
    bufSetQwordAt(surfInfo, 0, 1000217000)
    bufSetQwordAt(surfInfo, 8, 0)
    bufSetQwordAt(surfInfo, 16, 0)
    bufSetQwordAt(surfInfo, 24, layer)
    let rcS = vkCreateMetalSurfaceEXT(instance, surfInfo, 0, pSurface)
    print("n3b surface rc=" + rcS)
    let surface = bufGetQwordAt(pSurface, 0)
    // queue family detection (graphics + present)
    let pQF = bufNew(8)
    bufSetQwordAt(pQF, 0, 0)
    vkGetPhysicalDeviceQueueFamilyProperties(pDevice, pQF, 0)
    let qfCount = bufGetDwordAt(pQF, 0)
    let qfProps = bufNew(qfCount * 24)
    let pQFCount2 = bufNew(8)
    bufSetQwordAt(pQFCount2, 0, qfCount)
    vkGetPhysicalDeviceQueueFamilyProperties(pDevice, pQFCount2, qfProps)
    let queueFamily = 0 - 1
    let qi = 0
    while qi < qfCount {
        let flags = bufGetDwordAt(qfProps, qi * 24)
        if bitAnd(flags, 1) != 0 {
            let pSup = bufNew(4)
            bufSetDwordAt(pSup, 0, 0)
            vkGetPhysicalDeviceSurfaceSupportKHR(pDevice, qi, surface, pSup)
            if bufGetDwordAt(pSup, 0) == 1 {
                queueFamily = qi
                break
            }
        }
        qi += 1
    }
    print("queue family=" + queueFamily)
    // swapchain
    let caps = bufNew(52)
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pDevice, surface, caps)
    let minImages = bufGetDwordAt(caps, 0)
    let maxImages = bufGetDwordAt(caps, 4)
    let curW = bufGetDwordAt(caps, 8)
    let curH = bufGetDwordAt(caps, 12)
    print("caps: min=" + minImages + " max=" + maxImages + " extent=" + curW + "x" + curH)
    let pFmtCount = bufNew(8)
    bufSetQwordAt(pFmtCount, 0, 0)
    vkGetPhysicalDeviceSurfaceFormatsKHR(pDevice, surface, pFmtCount, 0)
    let fmtCount = bufGetDwordAt(pFmtCount, 0)
    let formats = bufNew(fmtCount * 8)
    let pFmtCount2 = bufNew(8)
    bufSetQwordAt(pFmtCount2, 0, fmtCount)
    vkGetPhysicalDeviceSurfaceFormatsKHR(pDevice, surface, pFmtCount2, formats)
    let imageFormat = bufGetDwordAt(formats, 0)
    let imageColorSpace = bufGetDwordAt(formats, 4)
    let fi = 0
    while fi < fmtCount {
        if bufGetDwordAt(formats, fi * 8) == 50 {
            imageFormat = 50
            imageColorSpace = bufGetDwordAt(formats, fi * 8 + 4)
            break
        }
        fi += 1
    }
    print("format: " + imageFormat + " colorSpace: " + imageColorSpace)
    let pPrio = bufNew(4)
    bufSetDwordAt(pPrio, 0, 1065353216)
    let qci = bufNew(40)
    bufSetQwordAt(qci, 0, 2)
    bufSetQwordAt(qci, 8, 0)
    bufSetQwordAt(qci, 16, 0)
    bufSetByte(qci, 20, 0)
    bufSetByte(qci, 21, 0)
    bufSetByte(qci, 22, 0)
    bufSetByte(qci, 23, 0)
    bufSetByte(qci, 24, 1)
    bufSetByte(qci, 25, 0)
    bufSetByte(qci, 26, 0)
    bufSetByte(qci, 27, 0)
    bufSetQwordAt(qci, 32, pPrio)
    let devExts = smackVkStrListBlock("VK_KHR_swapchain")
    let devInfo = bufNew(72)
    bufSetQwordAt(devInfo, 0, 3)
    bufSetQwordAt(devInfo, 8, 0)
    bufSetQwordAt(devInfo, 16, 0)
    bufSetByte(devInfo, 20, 1)
    bufSetByte(devInfo, 21, 0)
    bufSetByte(devInfo, 22, 0)
    bufSetByte(devInfo, 23, 0)
    bufSetQwordAt(devInfo, 24, qci)
    bufSetByte(devInfo, 32, 0)
    bufSetQwordAt(devInfo, 40, 0)
    bufSetByte(devInfo, 48, 1)
    bufSetByte(devInfo, 49, 0)
    bufSetByte(devInfo, 50, 0)
    bufSetByte(devInfo, 51, 0)
    bufSetQwordAt(devInfo, 56, devExts)
    bufSetQwordAt(devInfo, 64, 0)
    let pDev = bufNew(8)
    bufSetQwordAt(pDev, 0, 0)
    let rcD = vkCreateDevice(pDevice, devInfo, 0, pDev)
    print("n4 dev rc=" + rcD)
    let device = bufGetQwordAt(pDev, 0)
    let imageCount = minImages + 1
    if maxImages > 0 && imageCount > maxImages { imageCount = maxImages }
    if curW > 2000000000 { curW = 640; curH = 480 }
    let sci = bufNew(104)
    bufSetQwordAt(sci, 0, 1000001000)
    bufSetQwordAt(sci, 8, 0)
    bufSetByte(sci, 16, 0)
    bufSetByte(sci, 17, 0)
    bufSetByte(sci, 18, 0)
    bufSetByte(sci, 19, 0)
    bufSetQwordAt(sci, 24, surface)
    bufSetByte(sci, 32, imageCount)
    bufSetByte(sci, 33, 0)
    bufSetByte(sci, 34, 0)
    bufSetByte(sci, 35, 0)
    bufSetByte(sci, 36, imageFormat)
    bufSetByte(sci, 37, 0)
    bufSetByte(sci, 38, 0)
    bufSetByte(sci, 39, 0)
    bufSetByte(sci, 40, imageColorSpace)
    bufSetByte(sci, 41, 0)
    bufSetByte(sci, 42, 0)
    bufSetByte(sci, 43, 0)
    bufSetByte(sci, 44, curW)
    bufSetByte(sci, 45, 0)
    bufSetByte(sci, 46, 0)
    bufSetByte(sci, 47, 0)
    bufSetByte(sci, 48, curH)
    bufSetByte(sci, 49, 0)
    bufSetByte(sci, 50, 0)
    bufSetByte(sci, 51, 0)
    bufSetByte(sci, 52, 1)
    bufSetByte(sci, 53, 0)
    bufSetByte(sci, 54, 0)
    bufSetByte(sci, 55, 0)
    bufSetByte(sci, 56, 2)
    bufSetByte(sci, 57, 0)
    bufSetByte(sci, 58, 0)
    bufSetByte(sci, 59, 0)
    bufSetByte(sci, 60, 0)
    bufSetByte(sci, 61, 0)
    bufSetByte(sci, 62, 0)
    bufSetByte(sci, 63, 0)
    bufSetByte(sci, 64, 0)
    bufSetByte(sci, 65, 0)
    bufSetByte(sci, 66, 0)
    bufSetByte(sci, 67, 0)
    bufSetQwordAt(sci, 72, 0)
    bufSetByte(sci, 80, 1)
    bufSetByte(sci, 81, 0)
    bufSetByte(sci, 82, 0)
    bufSetByte(sci, 83, 0)
    bufSetByte(sci, 84, 1)
    bufSetByte(sci, 85, 0)
    bufSetByte(sci, 86, 0)
    bufSetByte(sci, 87, 0)
    bufSetByte(sci, 88, 2)
    bufSetByte(sci, 89, 0)
    bufSetByte(sci, 90, 0)
    bufSetByte(sci, 91, 0)
    bufSetByte(sci, 92, 1)
    bufSetByte(sci, 93, 0)
    bufSetByte(sci, 94, 0)
    bufSetByte(sci, 95, 0)
    bufSetQwordAt(sci, 96, 0)
    let pSwap = bufNew(8)
    bufSetQwordAt(pSwap, 0, 0)
    let rcSC = vkCreateSwapchainKHR(device, sci, 0, pSwap)
    print("swapchain rc=" + rcSC)
    let swapchain = bufGetQwordAt(pSwap, 0)
    let pQueue = bufNew(8)
    bufSetQwordAt(pQueue, 0, 0)
    vkGetDeviceQueue(device, queueFamily, 0, pQueue)
    let queue = bufGetQwordAt(pQueue, 0)
    print("queue ok")

    // ── SmackSurface scene + staging buffer ─────────────────────
    let surf = smackSurface(curW, curH)
    smackSurfaceClear(surf, colorRGB(16, 16, 48))
    smackSurfaceFillRect(surf, 20, 20, 600, 440, colorRGB(120, 120, 120))
    smackSurfaceFillRect(surf, 40, 40, 220, 160, colorRGB(255, 128, 0))
    smackSurfaceFillRect(surf, 300, 120, 280, 200, colorRGB(0, 200, 100))
    smackSurfaceFillRect(surf, 120, 300, 400, 120, colorRGB(200, 200, 200))
    smackSurfaceFillRect(surf, 150, 330, 100, 60, colorRGB(220, 60, 60))
    smackSurfaceStrokeRect(surf, 20, 20, 600, 440, colorRGB(255, 255, 255), 2)
    let staging = smackVkStagingCreate(device, pDevice, curW * curH * 4)
    if staging == "" { print("FAIL staging create"); exit("1") }
    let stagingRc = getField(staging, "rc")
    if stagingRc != 0 { print("FAIL staging rc=" + stagingRc); exit("1") }
    let upRc = smackVkStagingUpload(staging, smackSurfaceBuffer(surf), curW * curH * 4)
    if upRc != 1 { print("FAIL staging upload rc=" + upRc); exit("1") }
    print("surface uploaded: " + (curW * curH * 4) + " bytes")
    // query swapchain images
    let pImgCount = bufNew(8)
    bufSetQwordAt(pImgCount, 0, 0)
    vkGetSwapchainImagesKHR(device, swapchain, pImgCount, 0)
    let nImages = bufGetDwordAt(pImgCount, 0)
    let pImgCount2 = bufNew(8)
    bufSetQwordAt(pImgCount2, 0, nImages)
    let swapImages = bufNew(nImages * 8)
    vkGetSwapchainImagesKHR(device, swapchain, pImgCount2, swapImages)
    print("swapchain images: " + nImages)
    let cpInfo = bufNew(24)
    bufSetQwordAt(cpInfo, 0, 39)
    bufSetQwordAt(cpInfo, 8, 0)
    bufSetByte(cpInfo, 16, 0)
    bufSetByte(cpInfo, 17, 0)
    bufSetByte(cpInfo, 18, 0)
    bufSetByte(cpInfo, 19, 0)
    bufSetByte(cpInfo, 20, 0)
    bufSetByte(cpInfo, 21, 0)
    bufSetByte(cpInfo, 22, 0)
    bufSetByte(cpInfo, 23, 0)
    let pPool = bufNew(8)
    bufSetQwordAt(pPool, 0, 0)
    let rcCP = vkCreateCommandPool(device, cpInfo, 0, pPool)
    print("n5 pool rc=" + rcCP)
    let commandPool = bufGetQwordAt(pPool, 0)
    let cbAlloc = bufNew(32)
    bufSetQwordAt(cbAlloc, 0, 40)
    bufSetQwordAt(cbAlloc, 8, 0)
    bufSetQwordAt(cbAlloc, 16, commandPool)
    bufSetByte(cbAlloc, 24, 0)
    bufSetByte(cbAlloc, 25, 0)
    bufSetByte(cbAlloc, 26, 0)
    bufSetByte(cbAlloc, 27, 0)
    bufSetByte(cbAlloc, 28, 1)
    bufSetByte(cbAlloc, 29, 0)
    bufSetByte(cbAlloc, 30, 0)
    bufSetByte(cbAlloc, 31, 0)
    let cmdBufs = bufNew(8)
    bufSetQwordAt(cmdBufs, 0, 0)
    let rcAB = vkAllocateCommandBuffers(device, cbAlloc, cmdBufs)
    print("n6 ab rc=" + rcAB)
    let cmd = bufGetQwordAt(cmdBufs, 0)
    let beginI = bufNew(32)
    bufSetQwordAt(beginI, 0, 42)
    bufSetQwordAt(beginI, 8, 0)
    bufSetByte(beginI, 16, 1)
    bufSetQwordAt(beginI, 24, 0)
    let rcCB = vkBeginCommandBuffer(cmd, beginI)
    print("n7 begin rc=" + rcCB)
    bufSetQwordAt(barrier, 0, 45)
    bufSetQwordAt(barrier, 8, 0)
    bufSetQwordAt(barrier, 16, 0)
    bufSetQwordAt(barrier, 20, 4096)
    bufSetByte(barrier, 24, 0)
    bufSetByte(barrier, 28, 7)
    bufSetByte(barrier, 32, 255)
    bufSetByte(barrier, 36, 255)
    bufSetQwordAt(barrier, 40, 12345)
    bufSetByte(barrier, 48, 1)
    bufSetByte(barrier, 52, 0)
    bufSetByte(barrier, 56, 1)
    bufSetByte(barrier, 60, 0)
    bufSetByte(barrier, 64, 1)
    print("n8 barrier built")
    print("barrier[0]=" + bufGetByte(barrier, 0))
    print("barrier[63]=" + bufGetByte(barrier, 63))
    print("barrier[64]=" + bufGetByte(barrier, 64))
    print("barrier[65]=" + bufGetByte(barrier, 65))
    print("barrier[127]=" + bufGetByte(barrier, 127))
    // REAL image: use swapchain image 0 in the barrier
    bufSetQwordAt(barrier, 40, bufGetQwordAt(swapImages, 0))
    vkCmdPipelineBarrier(cmd,
        1, 4096, 0,
        0, 0,
        0, 0,
        1, barrier)
    // Copy SmackSurface pixels from the staging buffer into the swapchain image
    bufSetQwordAt(copyRegion, 0, 0)        // bufferOffset
    bufSetByte(copyRegion, 8, 0)           // bufferRowLength = 0 (tight)
    bufSetByte(copyRegion, 9, 0)
    bufSetByte(copyRegion, 10, 0)
    bufSetByte(copyRegion, 11, 0)
    bufSetByte(copyRegion, 12, 0)          // bufferImageHeight = 0 (tight)
    bufSetByte(copyRegion, 13, 0)
    bufSetByte(copyRegion, 14, 0)
    bufSetByte(copyRegion, 15, 0)
    bufSetByte(copyRegion, 16, 1)          // aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
    bufSetByte(copyRegion, 17, 0)
    bufSetByte(copyRegion, 18, 0)
    bufSetByte(copyRegion, 19, 0)
    bufSetByte(copyRegion, 20, 0)          // mipLevel
    bufSetByte(copyRegion, 21, 0)
    bufSetByte(copyRegion, 22, 0)
    bufSetByte(copyRegion, 23, 0)
    bufSetByte(copyRegion, 24, 0)          // baseArrayLayer
    bufSetByte(copyRegion, 25, 0)
    bufSetByte(copyRegion, 26, 0)
    bufSetByte(copyRegion, 27, 0)
    bufSetByte(copyRegion, 28, 1)          // layerCount = 1
    bufSetByte(copyRegion, 29, 0)
    bufSetByte(copyRegion, 30, 0)
    bufSetByte(copyRegion, 31, 0)
    bufSetByte(copyRegion, 32, 0)          // imageOffset.x
    bufSetByte(copyRegion, 33, 0)
    bufSetByte(copyRegion, 34, 0)
    bufSetByte(copyRegion, 35, 0)
    bufSetByte(copyRegion, 36, 0)          // .y
    bufSetByte(copyRegion, 37, 0)
    bufSetByte(copyRegion, 38, 0)
    bufSetByte(copyRegion, 39, 0)
    bufSetByte(copyRegion, 40, 0)          // .z
    bufSetByte(copyRegion, 41, 0)
    bufSetByte(copyRegion, 42, 0)
    bufSetByte(copyRegion, 43, 0)
    bufSetDwordAt(copyRegion, 44, curW)    // extent.width
    bufSetDwordAt(copyRegion, 48, curH)    // .height
    bufSetDwordAt(copyRegion, 52, 1)       // .depth
    vkCmdCopyBufferToImage(cmd, getField(staging, "buffer"), bufGetQwordAt(swapImages, 0), 7, 1, copyRegion)
    print("n9b copy survived")
    // second barrier: TRANSFER_DST -> PRESENT_SRC
    bufSetDwordAt(barrier, 24, 7)         // oldLayout
    bufSetDwordAt(barrier, 28, 1000001002) // VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    bufSetQwordAt(barrier, 16, 4096)      // srcAccessMask
    bufSetQwordAt(barrier, 20, 0)         // dstAccessMask
    vkCmdPipelineBarrier(cmd,
        4096, 8192, 0,
        0, 0,
        0, 0,
        1, barrier)
    print("n9c barrier2 survived")
    let rcEB = vkEndCommandBuffer(cmd)
    print("n10 end rc=" + rcEB)
    // present loop: record/submit once per acquire
    let pImageIndex = bufNew(4)
    bufSetDwordAt(pImageIndex, 0, 0)
    let submitInfo = bufNew(72)
    let stageMask = bufNew(4)
    bufSetDwordAt(stageMask, 0, 1024)  // VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    let cmds = bufNew(8)
    bufSetQwordAt(cmds, 0, cmd)
    bufSetQwordAt(submitInfo, 0, 4)    // VK_STRUCTURE_TYPE_SUBMIT_INFO
    bufSetQwordAt(submitInfo, 8, 0)
    bufSetDwordAt(submitInfo, 16, 0)
    bufSetQwordAt(submitInfo, 24, 0)
    bufSetQwordAt(submitInfo, 32, stageMask)
    bufSetDwordAt(submitInfo, 40, 1)
    bufSetQwordAt(submitInfo, 48, cmds)
    bufSetDwordAt(submitInfo, 56, 0)
    bufSetQwordAt(submitInfo, 64, 0)
    let presentInfo = bufNew(64)
    bufSetQwordAt(presentInfo, 0, 1000001001)  // VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
    bufSetQwordAt(presentInfo, 8, 0)
    bufSetDwordAt(presentInfo, 16, 0)
    bufSetQwordAt(presentInfo, 24, 0)
    bufSetDwordAt(presentInfo, 32, 1)
    let swaps = bufNew(8)
    bufSetQwordAt(swaps, 0, swapchain)
    bufSetQwordAt(presentInfo, 40, swaps)
    let indices = bufNew(4)
    bufSetDwordAt(indices, 0, 0)
    bufSetQwordAt(presentInfo, 48, indices)
    bufSetQwordAt(presentInfo, 56, 0)
    let frames = 0
    while frames < 90 {
        let rcAcq = vkAcquireNextImageKHR(device, swapchain, 1000000000, 0, 0, pImageIndex)
        // VK_SUCCESS (0) and VK_SUBOPTIMAL_KHR (1000001003) are both usable results
        if rcAcq != 0 && rcAcq != 1000001003 { print("acquire rc=" + rcAcq); break }
        let imageIndex = bufGetDwordAt(pImageIndex, 0)
        bufSetDwordAt(indices, 0, imageIndex)
        vkQueueSubmit(queue, 1, submitInfo, 0)
        let rcP = vkQueuePresentKHR(queue, presentInfo)
        if rcP != 0 && rcP != 1000001003 { print("present rc=" + rcP); break }
        frames += 1
    }
    print("presented " + frames + " frames")
}

just run {
    _runPresent()
}
