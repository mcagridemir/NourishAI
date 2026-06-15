// Sana — MetricsService.swift
// Subscribes to MetricKit so Apple delivers crash and hang diagnostics
// once per day (on the next app launch after an incident occurred).
// Reports are written to the app's Documents folder as JSON — no external
// SDK or network call required.
import MetricKit
import OSLog

private nonisolated let log = Logger(subsystem: "com.cagri.Sana", category: "Metrics")

nonisolated final class MetricsService: NSObject, MXMetricManagerSubscriber {

    static let shared = MetricsService()

    private let maxReports = 20
    private var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sana_diagnostics.jsonl")
    }

    override private init() {
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - Public

    /// All stored diagnostic summaries, newest first (for display in Settings).
    func storedReports() -> [String] {
        guard let data = try? Data(contentsOf: logURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .reversed()
    }

    func clearReports() {
        try? FileManager.default.removeItem(at: logURL)
    }

    // MARK: - Private

    private func append(_ entry: [String: Any]) {
        guard let line = try? JSONSerialization.data(withJSONObject: entry),
              let text = String(data: line, encoding: .utf8) else { return }

        var lines = storedReports().reversed().map { String($0) }
        lines.append(text)
        if lines.count > maxReports { lines = Array(lines.suffix(maxReports)) }

        let joined = lines.joined(separator: "\n") + "\n"
        try? joined.data(using: .utf8)?.write(to: logURL, options: .atomic)
    }
}

// MARK: - MXMetricManagerSubscriber

extension MetricsService {

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let version = payload.metaData?.applicationBuildVersion ?? ""
            let entry: [String: Any] = [
                "type": "metrics",
                "date": ISO8601DateFormatter().string(from: payload.timeStampEnd),
                "applicationVersion": version,
                "cpuTime": payload.cpuMetrics?.cumulativeCPUTime.converted(to: .seconds).value ?? 0,
                "memoryPeakMB": payload.memoryMetrics?.peakMemoryUsage.converted(to: .megabytes).value ?? 0,
                "launchBuckets": payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.totalBucketCount ?? 0
            ]
            append(entry)
            log.info("MetricKit payload received for version \(version)")
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let date = ISO8601DateFormatter().string(from: payload.timeStampEnd)

            for crash in payload.crashDiagnostics ?? [] {
                let version = crash.metaData.applicationBuildVersion
                let entry: [String: Any] = [
                    "type": "crash",
                    "date": date,
                    "applicationVersion": version,
                    "osVersion": crash.metaData.osVersion,
                    "exceptionType": crash.exceptionType?.description ?? "unknown",
                    "exceptionCode": crash.exceptionCode?.description ?? "",
                    "signal": crash.signal?.description ?? "",
                    "callStack": crash.callStackTree.jsonRepresentation().description
                ]
                append(entry)
                log.fault("Crash reported: \(crash.exceptionType?.description ?? "unknown") in build \(version)")
            }

            for hang in payload.hangDiagnostics ?? [] {
                let version = hang.metaData.applicationBuildVersion
                let entry: [String: Any] = [
                    "type": "hang",
                    "date": date,
                    "applicationVersion": version,
                    "durationMs": hang.hangDuration.converted(to: .milliseconds).value,
                    "callStack": hang.callStackTree.jsonRepresentation().description
                ]
                append(entry)
                log.error("Hang reported: \(hang.hangDuration.converted(to: .milliseconds).value, format: .fixed(precision: 0))ms in build \(version)")
            }

            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                let version = cpu.metaData.applicationBuildVersion
                let entry: [String: Any] = [
                    "type": "cpu_exception",
                    "date": date,
                    "applicationVersion": version,
                    "totalCPUTimeSec": cpu.totalCPUTime.converted(to: .seconds).value,
                    "totalSampledTimeSec": cpu.totalSampledTime.converted(to: .seconds).value
                ]
                append(entry)
                log.error("CPU exception: \(cpu.totalCPUTime.converted(to: .seconds).value, format: .fixed(precision: 1))s CPU in build \(version)")
            }

            for disk in payload.diskWriteExceptionDiagnostics ?? [] {
                let version = disk.metaData.applicationBuildVersion
                let entry: [String: Any] = [
                    "type": "disk_write_exception",
                    "date": date,
                    "applicationVersion": version,
                    "writtenMB": disk.totalWritesCaused.converted(to: .megabytes).value
                ]
                append(entry)
                log.error("Disk write exception: \(disk.totalWritesCaused.converted(to: .megabytes).value, format: .fixed(precision: 1))MB in build \(version)")
            }
        }
    }
}
