import Foundation
import CoreGraphics
import ImageIO
import Dispatch

public enum RPixelError: LocalizedError {
    case fileNotFound(String)
    case unreadableImage(String)
    case invalidDimensions(Int, Int)
    case noTransparentPixels
    case contextCreationFailed
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File does not exist: \(path)"
        case .unreadableImage(let path):
            return "Could not decode image at: \(path)"
        case .invalidDimensions(let w, let h):
            return "Invalid image dimensions: \(w)x\(h)"
        case .noTransparentPixels:
            return "No transparent pixels to fix"
        case .contextCreationFailed:
            return "Failed to create CoreGraphics bitmap context"
        case .exportFailed(let path):
            return "Failed to save fixed image to: \(path)"
        }
    }
}

public struct FixResult: Sendable {
    public let url: URL
    public let width: Int
    public let height: Int
    public let transparentCount: Int
    public let borderCount: Int
    public let durationSeconds: Double
    public let success: Bool
    public let errorMessage: String?

    public init(
        url: URL,
        width: Int = 0,
        height: Int = 0,
        transparentCount: Int = 0,
        borderCount: Int = 0,
        durationSeconds: Double = 0,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.transparentCount = transparentCount
        self.borderCount = borderCount
        self.durationSeconds = durationSeconds
        self.success = success
        self.errorMessage = errorMessage
    }
}

public final class AlphaFixer: @unchecked Sendable {
    public static let shared = AlphaFixer()

    private static let neighbors: [(Int, Int)] = [
        (-1, -1), (0, -1), (1, -1),
        (1, 0),            (1, 1),
        (0, 1),   (-1, 1), (-1, 0)
    ]

    private static let jfaOffsets: [(Int32, Int32)] = [
        (-1, -1), (0, -1), (1, -1),
        (-1,  0), (0,  0), (1,  0),
        (-1,  1), (0,  1), (1,  1)
    ]

    public init() {}

    /// Fixes alpha bleeding for a PNG image file at the given URL in-place.
    /// - Parameters:
    ///   - url: URL to the target PNG image.
    ///   - debug: If true, transparent pixels are assigned alpha = 255 to visualize dilated colors.
    /// - Returns: FixResult containing processing statistics.
    public func fixImage(at url: URL, debug: Bool = false) -> FixResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return FixResult(
                url: url,
                durationSeconds: CFAbsoluteTimeGetCurrent() - startTime,
                success: false,
                errorMessage: "Failed to open or decode image"
            )
        }

        let width = cgImage.width
        let height = cgImage.height

        guard width > 0 && height > 0 else {
            return FixResult(
                url: url,
                width: width,
                height: height,
                durationSeconds: CFAbsoluteTimeGetCurrent() - startTime,
                success: false,
                errorMessage: "Image has invalid dimensions: \(width)x\(height)"
            )
        }

        // Process image pixels
        var pixelData = extractRGBA8(from: cgImage)
        guard !pixelData.isEmpty else {
            return FixResult(
                url: url,
                width: width,
                height: height,
                durationSeconds: CFAbsoluteTimeGetCurrent() - startTime,
                success: false,
                errorMessage: "Failed to extract RGBA pixel buffer"
            )
        }

        let totalPixels = width * height
        var transparentIndices: [Int] = []
        transparentIndices.reserveCapacity(totalPixels / 2)

        var seedX = [Int32](repeating: -1, count: totalPixels)
        var seedY = [Int32](repeating: -1, count: totalPixels)
        var borderCount = 0

        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                let idx = rowOffset + x
                let pixelOffset = idx * 4
                let alpha = pixelData[pixelOffset + 3]

                if alpha == 0 {
                    transparentIndices.append(idx)
                    continue
                }

                // Check 8-way neighbors for transparency
                var isBorder = false
                for (nx, ny) in Self.neighbors {
                    let nX = x + nx
                    let nY = y + ny
                    if nX >= 0 && nX < width && nY >= 0 && nY < height {
                        let nOffset = (nY * width + nX) * 4
                        if pixelData[nOffset + 3] == 0 {
                            isBorder = true
                            break
                        }
                    }
                }

                if isBorder {
                    seedX[idx] = Int32(x)
                    seedY[idx] = Int32(y)
                    borderCount += 1
                }
            }
        }

        if borderCount == 0 || transparentIndices.isEmpty {
            return FixResult(
                url: url,
                width: width,
                height: height,
                transparentCount: transparentIndices.count,
                borderCount: borderCount,
                durationSeconds: CFAbsoluteTimeGetCurrent() - startTime,
                success: false,
                errorMessage: "No transparent border pixels to fix"
            )
        }

        // Run Jump Flooding Algorithm
        runJFA(
            width: width,
            height: height,
            seedX: &seedX,
            seedY: &seedY
        )

        // Dilate color into transparent pixels
        let targetAlpha: UInt8 = debug ? 255 : 0
        for idx in transparentIndices {
            let sX = seedX[idx]
            let sY = seedY[idx]
            if sX >= 0 && sY >= 0 {
                let srcOffset = (Int(sY) * width + Int(sX)) * 4
                let dstOffset = idx * 4
                pixelData[dstOffset + 0] = pixelData[srcOffset + 0]
                pixelData[dstOffset + 1] = pixelData[srcOffset + 1]
                pixelData[dstOffset + 2] = pixelData[srcOffset + 2]
                pixelData[dstOffset + 3] = targetAlpha
            }
        }

        // Export as PNG preserving non-premultiplied alpha
        guard saveRGBA8PNG(pixelData: pixelData, width: width, height: height, to: url) else {
            return FixResult(
                url: url,
                width: width,
                height: height,
                transparentCount: transparentIndices.count,
                borderCount: borderCount,
                durationSeconds: CFAbsoluteTimeGetCurrent() - startTime,
                success: false,
                errorMessage: "Failed to write fixed PNG file to disk"
            )
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        return FixResult(
            url: url,
            width: width,
            height: height,
            transparentCount: transparentIndices.count,
            borderCount: borderCount,
            durationSeconds: elapsed,
            success: true
        )
    }

    /// Process a CGImage in-memory without modifying files on disk.
    public func processInMemory(cgImage: CGImage, debug: Bool = false) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return nil }

        var pixelData = extractRGBA8(from: cgImage)
        guard !pixelData.isEmpty else { return nil }

        let totalPixels = width * height
        var transparentIndices: [Int] = []
        transparentIndices.reserveCapacity(totalPixels / 2)

        var seedX = [Int32](repeating: -1, count: totalPixels)
        var seedY = [Int32](repeating: -1, count: totalPixels)
        var borderCount = 0

        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                let idx = rowOffset + x
                let pixelOffset = idx * 4
                let alpha = pixelData[pixelOffset + 3]

                if alpha == 0 {
                    transparentIndices.append(idx)
                    continue
                }

                var isBorder = false
                for (nx, ny) in Self.neighbors {
                    let nX = x + nx
                    let nY = y + ny
                    if nX >= 0 && nX < width && nY >= 0 && nY < height {
                        let nOffset = (nY * width + nX) * 4
                        if pixelData[nOffset + 3] == 0 {
                            isBorder = true
                            break
                        }
                    }
                }

                if isBorder {
                    seedX[idx] = Int32(x)
                    seedY[idx] = Int32(y)
                    borderCount += 1
                }
            }
        }

        guard borderCount > 0 && !transparentIndices.isEmpty else { return nil }

        runJFA(
            width: width,
            height: height,
            seedX: &seedX,
            seedY: &seedY
        )

        let targetAlpha: UInt8 = debug ? 255 : 0
        for idx in transparentIndices {
            let sX = seedX[idx]
            let sY = seedY[idx]
            if sX >= 0 && sY >= 0 {
                let srcOffset = (Int(sY) * width + Int(sX)) * 4
                let dstOffset = idx * 4
                pixelData[dstOffset + 0] = pixelData[srcOffset + 0]
                pixelData[dstOffset + 1] = pixelData[srcOffset + 1]
                pixelData[dstOffset + 2] = pixelData[srcOffset + 2]
                pixelData[dstOffset + 3] = targetAlpha
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else { return nil }
        return CGImage(
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
        )
    }

    // MARK: - Internal Jump Flooding Algorithm

    private func runJFA(
        width: Int,
        height: Int,
        seedX: inout [Int32],
        seedY: inout [Int32]
    ) {
        var pingX = seedX
        var pingY = seedY
        var pongX = seedX
        var pongY = seedY

        var step = 1
        let maxDim = max(width, height)
        while step < maxDim { step *= 2 }
        step /= 2

        let offsets = Self.jfaOffsets

        pingX.withUnsafeMutableBufferPointer { pingXBuf in
        pingY.withUnsafeMutableBufferPointer { pingYBuf in
        pongX.withUnsafeMutableBufferPointer { pongXBuf in
        pongY.withUnsafeMutableBufferPointer { pongYBuf in
            var pX = pingXBuf.baseAddress!
            var pY = pingYBuf.baseAddress!
            var poX = pongXBuf.baseAddress!
            var poY = pongYBuf.baseAddress!

            while step >= 1 {
                let currentStep = Int32(step)
                DispatchQueue.concurrentPerform(iterations: height) { y in
                    let yInt32 = Int32(y)
                    let rowOffset = y * width
                    for x in 0..<width {
                        let xInt32 = Int32(x)
                        let idx = rowOffset + x

                        var bestDistSq: Int32 = Int32.max
                        var bestSx: Int32 = pX[idx]
                        var bestSy: Int32 = pY[idx]

                        if bestSx >= 0 {
                            let dxx = xInt32 - bestSx
                            let dyy = yInt32 - bestSy
                            bestDistSq = dxx * dxx + dyy * dyy
                        }

                        for (dx, dy) in offsets {
                            let nX = xInt32 + dx * currentStep
                            let nY = yInt32 + dy * currentStep

                            if nX >= 0 && nX < Int32(width) && nY >= 0 && nY < Int32(height) {
                                let nIdx = Int(nY) * width + Int(nX)
                                let sx = pX[nIdx]
                                let sy = pY[nIdx]
                                if sx >= 0 {
                                    let dxx = xInt32 - sx
                                    let dyy = yInt32 - sy
                                    let distSq = dxx * dxx + dyy * dyy
                                    if distSq < bestDistSq {
                                        bestDistSq = distSq
                                        bestSx = sx
                                        bestSy = sy
                                    }
                                }
                            }
                        }

                        poX[idx] = bestSx
                        poY[idx] = bestSy
                    }
                }

                swap(&pX, &poX)
                swap(&pY, &poY)
                step /= 2
            }

            // 1+JFA final refinement pass (step = 1)
            DispatchQueue.concurrentPerform(iterations: height) { y in
                let yInt32 = Int32(y)
                let rowOffset = y * width
                for x in 0..<width {
                    let xInt32 = Int32(x)
                    let idx = rowOffset + x

                    var bestDistSq: Int32 = Int32.max
                    var bestSx: Int32 = pX[idx]
                    var bestSy: Int32 = pY[idx]

                    if bestSx >= 0 {
                        let dxx = xInt32 - bestSx
                        let dyy = yInt32 - bestSy
                        bestDistSq = dxx * dxx + dyy * dyy
                    }

                    for (dx, dy) in offsets {
                        let nX = xInt32 + dx
                        let nY = yInt32 + dy

                        if nX >= 0 && nX < Int32(width) && nY >= 0 && nY < Int32(height) {
                            let nIdx = Int(nY) * width + Int(nX)
                            let sx = pX[nIdx]
                            let sy = pY[nIdx]
                            if sx >= 0 {
                                let dxx = xInt32 - sx
                                let dyy = yInt32 - sy
                                let distSq = dxx * dxx + dyy * dyy
                                if distSq < bestDistSq {
                                    bestDistSq = distSq
                                    bestSx = sx
                                    bestSy = sy
                                }
                            }
                        }
                    }

                    poX[idx] = bestSx
                    poY[idx] = bestSy
                }
            }

            swap(&pX, &poX)
            swap(&pY, &poY)
        }}}}

        seedX = pingX
        seedY = pingY
    }

    // MARK: - Pixel Buffer Extraction & Saving

    private func extractRGBA8(from cgImage: CGImage) -> [UInt8] {
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        var rawData = [UInt8](repeating: 0, count: totalPixels * 4)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bpc = cgImage.bitsPerComponent
        let bpp = cgImage.bitsPerPixel
        let bytesPerRow = cgImage.bytesPerRow

        // If the source image is already 32bpp 8bpc RGBA unpremultiplied, copy directly
        if bpc == 8 && bpp == 32 && (cgImage.alphaInfo == .last || cgImage.alphaInfo == .noneSkipLast),
           let dataProvider = cgImage.dataProvider,
           let cfData = dataProvider.data {
            let srcBytes = CFDataGetBytePtr(cfData)!
            for y in 0..<height {
                let srcRow = srcBytes + y * bytesPerRow
                for x in 0..<width {
                    let dstIdx = (y * width + x) * 4
                    let srcIdx = x * 4
                    rawData[dstIdx + 0] = srcRow[srcIdx + 0]
                    rawData[dstIdx + 1] = srcRow[srcIdx + 1]
                    rawData[dstIdx + 2] = srcRow[srcIdx + 2]
                    rawData[dstIdx + 3] = (cgImage.alphaInfo == .noneSkipLast) ? 255 : srcRow[srcIdx + 3]
                }
            }
            return rawData
        }

        // Otherwise render into a standard RGBA context
        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return rawData
    }

    private func saveRGBA8PNG(pixelData: [UInt8], width: Int, height: Int, to url: URL) -> Bool {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            return false
        }

        guard let outImage = CGImage(
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
        ) else {
            return false
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }

        CGImageDestinationAddImage(destination, outImage, nil)
        return CGImageDestinationFinalize(destination)
    }
}
