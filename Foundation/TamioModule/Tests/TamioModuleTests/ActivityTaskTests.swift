//
//  ActivityTaskTests.swift
//  TamioModuleTests
//
//  The steps an agent takes toward one task are kept as one entry.
//

@testable import TamioModule
import XCTest

@MainActor
final class ActivityTaskTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func run(_ command: String, at offset: TimeInterval, host: String = "web", client: String = "codex") -> AgentActivity {
        AgentActivity(
            date: start.addingTimeInterval(offset), device: "Mac", client: client, tool: "run_command",
            hosts: [host], hostNames: [host], summary: "Run on 1 server", detail: command, outcome: "exit 0 on 1",
            results: [.init(host: host, exitCode: 0, tail: "")]
        )
    }

    func testStepsOfOneTaskAreOneEntry() {
        let log = AgentActivityLog(file: nil)
        log.add(run("add-apt-repository ppa:ondrej/nginx", at: 0), task: "Install nginx")
        log.add(run("apt-get update", at: 60), task: "install nginx")
        log.add(run("apt-get install -y nginx", at: 120), task: "Install nginx")

        XCTAssertEqual(log.entries.count, 1)
        let entry = log.entries[0]
        XCTAssertEqual(entry.summary, "Install nginx")
        XCTAssertEqual(entry.steps?.count, 3)
        XCTAssertEqual(entry.detail, "$ add-apt-repository ppa:ondrej/nginx\n$ apt-get update\n$ apt-get install -y nginx")
        XCTAssertEqual(entry.outcome, "3 steps · last: exit 0 on 1")
        XCTAssertEqual(entry.date, start)
        XCTAssertEqual(entry.updated, start.addingTimeInterval(120))
    }

    func testAnotherTaskAnotherAgentOrNoTaskIsItsOwnEntry() {
        let log = AgentActivityLog(file: nil)
        log.add(run("apt-get install -y nginx", at: 0), task: "Install nginx")
        log.add(run("certbot --nginx", at: 30), task: "Set up HTTPS")
        log.add(run("apt-get install -y nginx", at: 60, client: "claude-code"), task: "Install nginx")
        log.add(run("uptime", at: 90), task: nil)

        XCTAssertEqual(log.entries.map(\.summary), ["Install nginx", "Set up HTTPS", "Install nginx", "Run on 1 server"])
    }

    func testATaskTakenUpLongAfterIsANewEntry() {
        let log = AgentActivityLog(file: nil)
        log.add(run("apt-get install -y nginx", at: 0), task: "Install nginx")
        log.add(run("apt-get install -y nginx", at: AgentActivityLog.taskGap + 1), task: "Install nginx")

        XCTAssertEqual(log.entries.count, 2)
    }

    func testATaskKeepsEveryServerItTouched() {
        let log = AgentActivityLog(file: nil)
        log.add(run("apt-get install -y nginx", at: 0, host: "web-1"), task: "Install nginx")
        log.add(run("apt-get install -y nginx", at: 10, host: "web-2"), task: "Install nginx")

        XCTAssertEqual(log.entries.first?.hostNames, ["web-1", "web-2"])
    }

    func testANewerCopyFromSyncReplacesTheOlder() {
        let log = AgentActivityLog(file: nil)
        log.add(run("apt-get update", at: 0), task: "Install nginx")
        var newer = log.entries[0]
        newer.steps?.append(run("apt-get install -y nginx", at: 60).asStep)
        newer.updated = start.addingTimeInterval(60)
        log.merge(newer)
        XCTAssertEqual(log.entries.first?.steps?.count, 2)

        log.merge(log.entries[0].withUpdated(start))
        XCTAssertEqual(log.entries.first?.steps?.count, 2)
    }
}

private extension AgentActivity {
    func withUpdated(_ date: Date) -> AgentActivity {
        var copy = self
        copy.steps = Array((copy.steps ?? []).prefix(1))
        copy.updated = date
        return copy
    }
}
