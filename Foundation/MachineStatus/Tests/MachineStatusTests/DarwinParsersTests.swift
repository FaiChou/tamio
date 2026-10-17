//
//  DarwinParsersTests.swift
//  MachineStatusTests
//

@testable import MachineStatus
import XCTest

final class DarwinParsersTests: XCTestCase {
    private let topFixture = """
    Processes: 700 total, 10 running, 690 sleeping, 3000 threads
    Load Avg: 1.11, 2.22, 3.33
    CPU usage: 10.0% user, 20.0% sys, 70.0% idle
    PhysMem: 10G used, 6G unused.
    Processes: 743 total, 14 running, 729 sleeping, 3558 threads
    Load Avg: 98.70, 115.18, 55.43
    CPU usage: 50.31% user, 32.91% sys, 16.77% idle
    PhysMem: 15G used, 90M unused.
    """

    func testTopUsesLastSampleForCPUAndLoad() {
        let processor = ServerStatus.ProcessorInfo(darwinTop: topFixture)
        XCTAssertEqual(processor?.summary.sumUser ?? 0, 50.31, accuracy: 0.001)
        XCTAssertEqual(processor?.summary.sumSystem ?? 0, 32.91, accuracy: 0.001)
        XCTAssertEqual(processor?.summary.sumUsed ?? 0, 83.23, accuracy: 0.001)
        XCTAssertEqual(processor?.cores.count, 0)

        let load = ProcParsers.parseDarwinTopLoad(topFixture)
        XCTAssertEqual(load.load1avg, 98.70, accuracy: 0.001)
        XCTAssertEqual(load.load5avg, 115.18, accuracy: 0.001)
        XCTAssertEqual(load.load15avg, 55.43, accuracy: 0.001)
        XCTAssertEqual(load.runningProcess, 14)
        XCTAssertEqual(load.totalProcess, 743)
    }

    func testMalformedTopReturnsNoReading() {
        XCTAssertNil(ServerStatus.ProcessorInfo(darwinTop: "not top output"))
        XCTAssertEqual(ProcParsers.parseDarwinTopLoad("not top output"), .init())
    }

    func testDarwinMemoryUsesPageSizeAndSwapUnits() {
        let fixture = """
        hw.memsize: 17179869184
        hw.pagesize: 16384
        vm.swapusage: total = 2048.00M  used = 512.00M  free = 1536.00M  (encrypted)
        Mach Virtual Memory Statistics: (page size of 16384 bytes)
        Pages free:                                     4497.
        Pages speculative:                              1547.
        Pages occupied by compressor:                  21904.
        File-backed pages:                            407513.
        Anonymous pages:                              486560.
        """
        let memory = ServerStatus.MemoryInfo(darwinMemory: fixture)
        XCTAssertEqual(memory.memTotal, 16_777_216)
        XCTAssertEqual(memory.memFree, 96704)
        XCTAssertEqual(memory.memCached, 6_495_456)
        XCTAssertEqual(memory.memBuffers, 0)
        XCTAssertEqual(memory.swapTotal, 2_097_152)
        XCTAssertEqual(memory.swapFree, 1_572_864)
        XCTAssertEqual(memory.swapUsed, 0.25, accuracy: 0.001)
        XCTAssertGreaterThan(memory.phyUsed, 0)
        XCTAssertLessThan(memory.phyUsed, 1)
    }

    func testDarwinMemoryFallsBackToVMStatPageSize() {
        let fixture = """
        hw.memsize: 8589934592
        Mach Virtual Memory Statistics: (page size of 4096 bytes)
        Pages free: 1000.
        Pages speculative: 500.
        File-backed pages: 2000.
        """
        let memory = ServerStatus.MemoryInfo(darwinMemory: fixture)
        XCTAssertEqual(memory.memFree, 6000)
        XCTAssertEqual(memory.memCached, 6000)
    }

    func testDarwinNetstatReadsLinkRowsAndOptionalAddressColumn() {
        let before = """
        Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
        lo0        16384 <Link#1>                          10     0       100       10     0       100     0
        en0        1500  <Link#11>   be:c4:9b:88:a5:08    20     0      1000       30     0      2000     0
        gif0*      1280  <Link#2>                             0     0         0        0     0         0     0
        en0        1500  192.168.31    192.168.31.241      20     -      1000       30     -      2000     -
        """
        let after = """
        lo0        16384 <Link#1>                          15     0       150       20     0       250     0
        en0        1500  <Link#11>   be:c4:9b:88:a5:08    25     0      3000       40     0      6000     0
        gif0       1280  <Link#2>                             1     0        64        2     0       128     0
        """
        let network = ServerStatus.NetworkInfo(netstatBefore: before, netstatAfter: after)
        XCTAssertEqual(network?.elements.count, 3)
        XCTAssertEqual(network?.elements.first { $0.device == "en0" }?.rxBytesPerSec, 2000)
        XCTAssertEqual(network?.elements.first { $0.device == "en0" }?.txBytesPerSec, 4000)
        XCTAssertEqual(network?.elements.first { $0.device == "lo0" }?.rxBytesPerSec, 50)
        XCTAssertEqual(network?.elements.first { $0.device == "gif0" }?.txBytesPerSec, 128)
    }

    func testDarwinUptimeAndReleaseName() {
        let uptime = "1000\n{ sec = 750, usec = 912078 } Sat Oct 17 21:39:26 2026\n"
        XCTAssertEqual(ProcParsers.parseDarwinUptime(uptime), 250)
        XCTAssertEqual(ProcParsers.parseDarwinUptime("garbage"), 0)

        let release = """
        ProductName:            macOS
        ProductVersion:         27.2
        BuildVersion:           26B5112a
        """
        XCTAssertEqual(ProcParsers.parseDarwinReleaseName(release), "macOS 27.2")
    }

    func testMonitorScriptContainsDarwinProbesAndLinuxFallbacks() {
        let script = ServerStatus.monitorScript(includeStatic: true)
        XCTAssertTrue(script.contains("/usr/bin/top -l 2 -n 0 -s 1"))
        XCTAssertTrue(script.contains("/usr/sbin/netstat -ibn"))
        XCTAssertTrue(script.contains("/usr/bin/vm_stat"))
        XCTAssertTrue(script.contains("vm.swapusage"))
        XCTAssertTrue(script.contains("/usr/bin/sw_vers"))
        XCTAssertTrue(script.contains("kern.boottime"))
        XCTAssertTrue(script.contains("/bin/cat /proc/meminfo"))
    }
}
