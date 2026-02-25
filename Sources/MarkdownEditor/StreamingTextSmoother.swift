import Foundation

/// Smooths streaming "full text so far" updates into a steadier character cadence.
/// Call `ingest(_:)` with cumulative text, and `start()` to begin ticking.
@MainActor
public final class StreamingTextSmoother {
    private struct Sample {
        let time: CFTimeInterval
        let count: Int
    }

    private let tickInterval: TimeInterval
    private let rateWindow: TimeInterval
    private let maxLag: TimeInterval
    private let minRate: Double
    private let setText: (String) -> Void
    private var latestText = ""
    private var displayedCount = 0
    private var samples: [Sample] = []
    private var lastRate: Double = 0
    private var tickTask: Task<Void, Never>?

    public var isRunning: Bool { tickTask != nil }

    public init(
        tickHz: Double = 60,
        rateWindow: TimeInterval = 0.35,
        maxLag: TimeInterval = 0.2,
        minRate: Double = 12,
        setText: @escaping (String) -> Void
    ) {
        self.tickInterval = 1.0 / tickHz
        self.rateWindow = rateWindow
        self.maxLag = maxLag
        self.minRate = minRate
        self.setText = setText
    }

    /// Starts the background cadence loop.
    public func start() {
        guard tickTask == nil else { return }
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                self.tick()
                try? await Task.sleep(nanoseconds: UInt64(self.tickInterval * 1_000_000_000))
            }
        }
    }

    /// Adds a new cumulative text snapshot to smooth.
    public func ingest(_ text: String) {
        let now = CFAbsoluteTimeGetCurrent()
        if text.count < latestText.count {
            latestText = text
            displayedCount = min(displayedCount, text.count)
        } else {
            latestText = text
        }
        samples.append(Sample(time: now, count: text.count))
        pruneSamples(now: now)
    }

    /// Immediately applies the latest text and stops smoothing.
    public func applyFinal() {
        let finalText = latestText
        displayedCount = finalText.count
        setText(finalText)
        cancel()
    }

    /// Stops the smoothing loop.
    public func cancel() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        let targetCount = latestText.count
        let lag = targetCount - displayedCount
        guard lag > 0 else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let rate = estimateRate(now: now)
        let catchUpRate = max(rate, Double(lag) / maxLag)
        let step = max(1, Int(catchUpRate * tickInterval))
        displayedCount = min(targetCount, displayedCount + step)
        setText(String(latestText.prefix(displayedCount)))
    }

    private func estimateRate(now: CFTimeInterval) -> Double {
        pruneSamples(now: now)
        guard let first = samples.first, let last = samples.last, last.time > first.time else {
            return max(lastRate, minRate)
        }

        let deltaCount = max(0, last.count - first.count)
        let deltaTime = max(0.001, last.time - first.time)
        let instantRate = Double(deltaCount) / deltaTime
        lastRate = lastRate == 0 ? instantRate : (lastRate * 0.65 + instantRate * 0.35)
        return max(lastRate, minRate)
    }

    private func pruneSamples(now: CFTimeInterval) {
        let cutoff = now - rateWindow
        if let index = samples.firstIndex(where: { $0.time >= cutoff }) {
            if index > 0 {
                samples.removeFirst(index)
            }
        } else {
            samples.removeAll(keepingCapacity: true)
        }
    }
}
