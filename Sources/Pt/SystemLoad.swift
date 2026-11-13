import Darwin
import Foundation
import IOKit

struct SystemLoad {
    private let host = mach_host_self()
    private var previous: (busy: UInt32, total: UInt32)?

    mutating func sample() -> Double {
        max(cpu() ?? 0, Self.gpu() ?? 0)
    }

    mutating func cpu() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = info.cpu_ticks
        let busy = ticks.0 &+ ticks.1 &+ ticks.3
        let total = busy &+ ticks.2
        defer { previous = (busy, total) }
        guard let previous else { return nil }
        return Self.usage(busy: busy &- previous.busy, total: total &- previous.total)
    }

    static func usage(busy: UInt32, total: UInt32) -> Double? {
        guard total > 0 else { return nil }
        return min(1, max(0, Double(busy) / Double(total)))
    }

    static func gpu() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var highest: Double?
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            guard let statistics = IORegistryEntryCreateCFProperty(
                    service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any],
                  let utilization = statistics["Device Utilization %"] as? NSNumber else { continue }
            highest = max(highest ?? 0, min(1, max(0, utilization.doubleValue / 100)))
        }
        return highest
    }
}
