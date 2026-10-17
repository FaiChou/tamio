//
//  DarwinParsers.swift
//  MachineStatus
//

import Foundation

extension ProcParsers {
    private static func lastLine(in raw: String, prefix: String) -> String? {
        raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { $0.hasPrefix(prefix) }
    }

    static func parseDarwinCPU(_ raw: String) -> ServerStatus.ProcessPercentInfo? {
        guard let line = lastLine(in: raw, prefix: "CPU usage:") else { return nil }
        var percentages = [String: Float]()
        for component in String(line.dropFirst("CPU usage:".count)).split(separator: ",") {
            let fields = splitWhitespaceRuns(String(component))
            guard fields.count == 2,
                  fields[0].hasSuffix("%"),
                  let value = Float(fields[0].dropLast())
            else {
                continue
            }
            percentages[String(fields[1])] = value
        }
        guard let user = percentages["user"],
              let system = percentages["sys"],
              let idle = percentages["idle"]
        else {
            return nil
        }
        return .init(system: system, user: user, iowait: 0, nice: 0, sum: max(0, 100 - idle))
    }

    static func parseDarwinTopLoad(_ raw: String) -> ServerStatus.SystemLoadInternal {
        var result = ServerStatus.SystemLoadInternal()
        guard let loadLine = lastLine(in: raw, prefix: "Load Avg:"),
              let processesLine = lastLine(in: raw, prefix: "Processes:")
        else {
            return result
        }
        let loads = splitWhitespaceRuns(String(loadLine.dropFirst("Load Avg:".count)))
        let processes = splitWhitespaceRuns(processesLine)
        guard loads.count == 3,
              let load1 = Float(loads[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))),
              let load5 = Float(loads[1].trimmingCharacters(in: CharacterSet(charactersIn: ","))),
              let load15 = Float(loads[2].trimmingCharacters(in: CharacterSet(charactersIn: ","))),
              processes.count >= 5,
              let total = Int(processes[1]),
              let running = Int(processes[3])
        else {
            return result
        }
        result.load1avg = load1
        result.load5avg = load5
        result.load15avg = load15
        result.runningProcess = running
        result.totalProcess = total
        return result
    }

    static func parseDarwinUptime(_ raw: String) -> Double {
        let fields = splitWhitespaceRuns(raw)
        guard let now = fields.first.flatMap({ Double($0) }),
              let secIndex = fields.firstIndex(of: "sec"),
              secIndex + 2 < fields.count,
              fields[secIndex + 1] == "=",
              let boot = Double(fields[secIndex + 2].trimmingCharacters(in: CharacterSet(charactersIn: ",")))
        else {
            return 0
        }
        return max(0, now - boot)
    }

    static func parseDarwinReleaseName(_ raw: String) -> String {
        var productName: String?
        var productVersion: String?
        for line in raw.components(separatedBy: "\n") {
            let fields = line.split(separator: ":", maxSplits: 1)
            guard fields.count == 2 else { continue }
            let key = fields[0].trimmingCharacters(in: .whitespaces)
            let value = fields[1].trimmingCharacters(in: .whitespaces)
            if key == "ProductName" {
                productName = value
            }
            if key == "ProductVersion" {
                productVersion = value
            }
        }
        if let productName, let productVersion {
            return "\(productName) \(productVersion)"
        }
        return productName ?? "macOS"
    }

    private static func parseDarwinKilobytes(_ token: Substring) -> Double {
        let text = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unit = text.last else { return 0 }
        let scales = ["K": 1.0, "M": 1024.0, "G": 1_048_576.0, "T": 1_073_741_824.0]
        if let scale = scales[String(unit).uppercased()], let value = Double(text.dropLast()) {
            return value * scale
        }
        return Double(text) ?? 0
    }

    static func parseDarwinMemory(_ raw: String) -> (
        total: Double, free: Double, cached: Double, swapTotal: Double, swapFree: Double
    ) {
        var total = 0.0
        var pageSize = 0.0
        var pages = [String: Double]()
        var swapTotal = 0.0
        var swapFree = 0.0

        for line in raw.components(separatedBy: "\n") {
            let fields = line.split(separator: ":", maxSplits: 1)
            guard fields.count == 2 else { continue }
            let key = fields[0].trimmingCharacters(in: .whitespaces)
            let value = fields[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "hw.memsize":
                total = (Double(value) ?? 0) / 1024
            case "hw.pagesize":
                pageSize = Double(value) ?? 0
            case "vm.swapusage":
                let swapFields = splitWhitespaceRuns(value)
                if let index = swapFields.firstIndex(of: "total"), index + 2 < swapFields.count {
                    swapTotal = parseDarwinKilobytes(swapFields[index + 2])
                }
                if let index = swapFields.firstIndex(of: "free"), index + 2 < swapFields.count {
                    swapFree = parseDarwinKilobytes(swapFields[index + 2])
                }
            case "Pages free", "Pages speculative", "File-backed pages":
                pages[key] = Double(value.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
            default:
                continue
            }
        }

        if pageSize == 0,
           let header = raw.components(separatedBy: "\n").first(where: { $0.contains("page size of") })
        {
            let fields = splitWhitespaceRuns(header)
            if let index = fields.firstIndex(of: "of"), index + 1 < fields.count {
                pageSize = Double(fields[index + 1]) ?? 0
            }
        }
        let freePages = (pages["Pages free"] ?? 0) + (pages["Pages speculative"] ?? 0)
        let cachedPages = max(0, (pages["File-backed pages"] ?? 0) - (pages["Pages speculative"] ?? 0))
        let kilobytesPerPage = pageSize / 1024
        return (
            total: total,
            free: freePages * kilobytesPerPage,
            cached: cachedPages * kilobytesPerPage,
            swapTotal: swapTotal,
            swapFree: swapFree
        )
    }

    static func parseDarwinNetstat(_ raw: String) -> [String: (rx: Int, tx: Int)] {
        var result = [String: (rx: Int, tx: Int)]()
        for line in raw.components(separatedBy: "\n") {
            let fields = splitWhitespaceRuns(line)
            guard fields.count >= 10,
                  fields[2].hasPrefix("<Link#"),
                  let rx = Int(fields[fields.count - 5]),
                  let tx = Int(fields[fields.count - 2])
            else {
                continue
            }
            var device = String(fields[0])
            if device.hasSuffix("*") {
                device.removeLast()
            }
            result[device] = (rx, tx)
        }
        return result
    }
}
