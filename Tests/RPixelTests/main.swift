import Foundation
import CoreGraphics
import ImageIO
import RPixelCore

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("❌ FAILED: \(message)")
        exit(1)
    } else {
        print("  ✓ \(message)")
    }
}

func createTestPNG(
    in dir: URL,
    width: Int,
    height: Int,
    solidRect: CGRect,
    solidColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
    transparentColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) = (0, 0, 0, 0)
) throws -> URL {
    let total = width * height
    var bytes = [UInt8](repeating: 0, count: total * 4)

    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * width + x) * 4
            if solidRect.contains(CGPoint(x: x, y: y)) {
                bytes[idx + 0] = solidColor.r
                bytes[idx + 1] = solidColor.g
                bytes[idx + 2] = solidColor.b
                bytes[idx + 3] = solidColor.a
            } else {
                bytes[idx + 0] = transparentColor.r
                bytes[idx + 1] = transparentColor.g
                bytes[idx + 2] = transparentColor.b
                bytes[idx + 3] = transparentColor.a
            }
        }
    }

    let fileURL = dir.appendingPathComponent("\(UUID().uuidString).png")
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          ),
          let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, "public.png" as CFString, 1, nil) else {
        throw RPixelError.contextCreationFailed
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RPixelError.exportFailed(fileURL.path)
    }
    return fileURL
}

print("🧪 Running RPixel Test Suite...\n")

let rootTempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: rootTempDir, withIntermediateDirectories: true)

// Test 1: Border Detection and Dilation
print("1. Testing Border Detection and Voronoi Dilation...")
do {
    let dir1 = rootTempDir.appendingPathComponent("test1", isDirectory: true)
    try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
    let fileURL = try createTestPNG(
        in: dir1,
        width: 16,
        height: 16,
        solidRect: CGRect(x: 4, y: 4, width: 8, height: 8),
        solidColor: (255, 128, 0, 255)
    )

    let result = AlphaFixer.shared.fixImage(at: fileURL, debug: false)
    expect(result.success, "Image fix should succeed")
    expect(result.width == 16 && result.height == 16, "Dimensions should match")
    expect(result.transparentCount > 0, "Transparent pixels should be found")
    expect(result.borderCount > 0, "Border pixels should be detected")

    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
          let loaded = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let cfData = loaded.dataProvider?.data else {
        fatalError("Failed to reload fixed image")
    }

    let bytes = [UInt8](cfData as Data)
    expect(bytes[0] == 255, "R channel dilated to outer transparent pixel")
    expect(bytes[1] == 128, "G channel dilated to outer transparent pixel")
    expect(bytes[2] == 0, "B channel dilated to outer transparent pixel")
    expect(bytes[3] == 0, "Alpha channel remains 0 in standard mode")
}

// Test 2: Debug Mode
print("\n2. Testing Debug Mode (Alpha = 255)...")
do {
    let dir2 = rootTempDir.appendingPathComponent("test2", isDirectory: true)
    try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
    let fileURL = try createTestPNG(
        in: dir2,
        width: 16,
        height: 16,
        solidRect: CGRect(x: 4, y: 4, width: 8, height: 8),
        solidColor: (0, 200, 100, 255)
    )

    let result = AlphaFixer.shared.fixImage(at: fileURL, debug: true)
    expect(result.success, "Debug fix should succeed")

    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
          let loaded = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let cfData = loaded.dataProvider?.data else {
        fatalError("Failed to reload fixed image")
    }

    let bytes = [UInt8](cfData as Data)
    expect(bytes[0] == 0, "R channel correct")
    expect(bytes[1] == 200, "G channel correct")
    expect(bytes[2] == 100, "B channel correct")
    expect(bytes[3] == 255, "Alpha channel set to 255 in debug mode")
}

// Test 3: Completely opaque image
print("\n3. Testing Opaque Image (No Transparent Pixels)...")
do {
    let dir3 = rootTempDir.appendingPathComponent("test3", isDirectory: true)
    try FileManager.default.createDirectory(at: dir3, withIntermediateDirectories: true)
    let fileURL = try createTestPNG(
        in: dir3,
        width: 8,
        height: 8,
        solidRect: CGRect(x: 0, y: 0, width: 8, height: 8),
        solidColor: (255, 255, 255, 255)
    )

    let result = AlphaFixer.shared.fixImage(at: fileURL, debug: false)
    expect(!result.success, "Opaque image should not be modified")
    expect(result.errorMessage == "No transparent border pixels to fix", "Correct error message returned")
}

// Test 4: File Resolver
print("\n4. Testing File Resolver...")
do {
    let dir4 = rootTempDir.appendingPathComponent("test4", isDirectory: true)
    try FileManager.default.createDirectory(at: dir4, withIntermediateDirectories: true)

    let png1 = dir4.appendingPathComponent("test1.png")
    let png2 = dir4.appendingPathComponent("test2.PNG")
    let txt = dir4.appendingPathComponent("note.txt")

    try "dummy".write(to: png1, atomically: true, encoding: .utf8)
    try "dummy".write(to: png2, atomically: true, encoding: .utf8)
    try "dummy".write(to: txt, atomically: true, encoding: .utf8)

    let resolved = FileResolver.resolve(paths: [dir4.path], recursive: false)
    expect(resolved.pngURLs.count == 2, "Found both lowercase and uppercase .png files")
    expect(resolved.skippedNonPNGURLs.count == 1, "Skipped .txt file")
    expect(resolved.skippedCount == 1, "Correct skipped count")
}

// Test 5: Quick Action Workflow Generation
print("\n5. Testing Finder Quick Action Generation...")
do {
    let workflowURL = try QuickActionManager.install()
    expect(FileManager.default.fileExists(atPath: workflowURL.path), "Workflow bundle exists in ~/Library/Services")
    expect(QuickActionManager.isInstalled, "QuickActionManager reports installed")

    let wflowFile = workflowURL.appendingPathComponent("Contents/Resources/document.wflow")
    expect(FileManager.default.fileExists(atPath: wflowFile.path), "document.wflow created")

    let infoPlist = workflowURL.appendingPathComponent("Contents/Info.plist")
    expect(FileManager.default.fileExists(atPath: infoPlist.path), "Info.plist created")
}

// Cleanup
try? FileManager.default.removeItem(at: rootTempDir)

print("\n🎉 ALL TESTS PASSED SUCCESSFULLY!\n")
