//
//  SSI+MemoryInfo.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import Foundation

public extension ServerStatus {
    /// 服务器 RAM 信息
    struct MemoryInfo: Codable, Equatable, Identifiable {
        public var id = UUID()

        public let memTotal: Double
        public let memFree: Double
        public let memBuffers: Double
        public let memCached: Double
        public let swapTotal: Double
        public let swapFree: Double
        public let phyUsed: Double
        public let swapUsed: Double
        public init() {
            memTotal = 0
            memFree = 0
            memBuffers = 0
            memCached = 0
            swapTotal = 0
            swapFree = 0
            phyUsed = 0
            swapUsed = 0
        }

        public init(total: Double, free: Double, buffers: Double, cached: Double, swapTotal: Double, swapFree: Double) {
            memTotal = total
            memFree = free
            memBuffers = buffers
            memCached = cached
            self.swapTotal = swapTotal
            self.swapFree = swapFree
            if total != 0 {
                phyUsed = (
                    (total - free - memCached - memBuffers) / total
                )
            } else {
                phyUsed = 0
            }
            // Swap usage is relative to swapTotal, not physical memory,
            // and machines without swap must not divide by zero.
            if swapTotal != 0 {
                swapUsed = (
                    (swapTotal - swapFree) / swapTotal
                )
            } else {
                swapUsed = 0
            }
        }

        public init(meminfo: String) {
            let info = ProcParsers.parseMeminfo(meminfo)
            self.init(
                total: info["MemTotal".uppercased()] ?? 0,
                free: info["MemFree".uppercased()] ?? 0,
                buffers: info["Buffers".uppercased()] ?? 0,
                cached: info["Cached".uppercased()] ?? 0,
                swapTotal: info["SwapTotal".uppercased()] ?? 0,
                swapFree: info["SwapFree".uppercased()] ?? 0
            )
        }

        public func description() -> String {
            """
            total: \(Int(exactly: memTotal) ?? 0) kB
            free: \(Int(exactly: memFree) ?? 0) kB
            buffers: \(Int(exactly: memBuffers) ?? 0) kB
            cached: \(Int(exactly: memCached) ?? 0) kB
            swap: \(Int(exactly: swapFree) ?? 0)/\(Int(exactly: swapTotal) ?? 0) kB
            """
        }
    }
}
