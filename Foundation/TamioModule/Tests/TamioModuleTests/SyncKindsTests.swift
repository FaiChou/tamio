//
//  SyncKindsTests.swift
//  TamioModuleTests
//
//  Snippets, port forwards, known hosts and agent activity, synced between
//  two devices like servers and identities are.
//

@testable import TamioModule
import XCTest

final class SyncKindsTests: XCTestCase {
    /// A device with only the kinds these tests sync.
    private struct Device {
        var snippets: [RDSnippet] = []
        var forwards: [RDPortForward] = []
        var hosts: [KnownHostEntry] = []
        var activity: [AgentActivity] = []
        var clearedAt: Date?
        var state = SyncState()
        var key: SyncCipher.Key?

        mutating func sync(_ cloud: inout Data?, at now: Date) {
            var input = SyncInput(
                machines: [], identities: [], state: state, passphrase: "correct horse battery", remote: cloud, key: key
            )
            input.snippets = snippets
            input.portForwards = forwards
            input.knownHosts = hosts
            input.activity = activity
            input.activityClearedAt = clearedAt
            input.now = now
            input.rounds = 1000
            input.minimumRounds = 1000
            guard case let .done(done) = SyncSession.run(input) else { return XCTFail("sync failed") }
            apply(done.snippets, to: &snippets)
            apply(done.portForwards, to: &forwards)
            apply(done.knownHosts, to: &hosts)
            activity = (activity + done.activity).sorted { $0.date < $1.date }
            state = done.state
            key = done.key
            if let upload = done.upload { cloud = upload }
        }

        private func apply<Value: Identifiable>(_ changes: [SyncChange<Value>], to items: inout [Value]) where Value.ID == UUID {
            for change in changes {
                switch change {
                case let .put(value):
                    items.removeAll { $0.id == value.id }
                    items.append(value)
                case let .remove(id):
                    items.removeAll { $0.id == id }
                }
            }
        }
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ summary: String, at date: Date, tail: String = "") -> AgentActivity {
        AgentActivity(
            date: date, device: "Mac", client: "test", tool: "run_command", hosts: [], hostNames: [],
            summary: summary, detail: "", outcome: "exit 0",
            results: [.init(host: "a", exitCode: 0, tail: tail)]
        )
    }

    func testSnippetsPortForwardsAndKnownHostsReachTheOtherDevice() {
        var cloud: Data?
        var mine = Device()
        mine.snippets = [RDSnippet(name: "uptime", code: "uptime")]
        mine.forwards = [RDPortForward(bindPort: 8080, targetHost: "localhost", targetPort: 80)]
        mine.hosts = [KnownHostEntry(name: "[example.com]:22", line: "ssh-ed25519 AAAA")]
        mine.sync(&cloud, at: start)

        var theirs = Device()
        theirs.sync(&cloud, at: start.addingTimeInterval(1))
        XCTAssertEqual(theirs.snippets.map(\.code), ["uptime"])
        XCTAssertEqual(theirs.forwards.map(\.bindPort), [8080])
        XCTAssertEqual(theirs.hosts, mine.hosts)
    }

    func testAForgottenHostKeyIsForgottenEverywhere() {
        var cloud: Data?
        var mine = Device()
        mine.hosts = [KnownHostEntry(name: "[example.com]:22", line: "ssh-ed25519 AAAA")]
        mine.sync(&cloud, at: start)
        var theirs = Device()
        theirs.sync(&cloud, at: start.addingTimeInterval(1))
        XCTAssertEqual(theirs.hosts.count, 1)

        mine.hosts = []
        mine.sync(&cloud, at: start.addingTimeInterval(2))
        theirs.sync(&cloud, at: start.addingTimeInterval(3))
        XCTAssertTrue(theirs.hosts.isEmpty)
    }

    func testAKnownHostHasTheSameIDOnEveryDevice() {
        XCTAssertEqual(
            KnownHostEntry(name: "[example.com]:22", line: "a").id,
            KnownHostEntry(name: "[example.com]:22", line: "b").id
        )
        XCTAssertNotEqual(KnownHostEntry(name: "[a]:22", line: "a").id, KnownHostEntry(name: "[b]:22", line: "a").id)
    }

    func testActivityOfBothDevicesIsKeptTogether() {
        var cloud: Data?
        var mine = Device()
        var theirs = Device()
        mine.activity = [entry("mine", at: start)]
        theirs.activity = [entry("theirs", at: start.addingTimeInterval(5))]
        mine.sync(&cloud, at: start.addingTimeInterval(10))
        theirs.sync(&cloud, at: start.addingTimeInterval(11))
        mine.sync(&cloud, at: start.addingTimeInterval(12))
        XCTAssertEqual(mine.activity.map(\.summary), ["mine", "theirs"])
        XCTAssertEqual(theirs.activity.map(\.summary), ["mine", "theirs"])
    }

    func testClearingActivityHereDoesNotBringItBackOrClearItElsewhere() {
        var cloud: Data?
        var mine = Device()
        var theirs = Device()
        mine.activity = [entry("old", at: start)]
        mine.sync(&cloud, at: start.addingTimeInterval(1))
        theirs.sync(&cloud, at: start.addingTimeInterval(2))

        mine.activity = []
        mine.clearedAt = start.addingTimeInterval(3)
        mine.sync(&cloud, at: start.addingTimeInterval(4))
        XCTAssertTrue(mine.activity.isEmpty)

        theirs.sync(&cloud, at: start.addingTimeInterval(5))
        XCTAssertEqual(theirs.activity.map(\.summary), ["old"])

        theirs.activity.append(entry("new", at: start.addingTimeInterval(6)))
        theirs.sync(&cloud, at: start.addingTimeInterval(7))
        mine.sync(&cloud, at: start.addingTimeInterval(8))
        XCTAssertEqual(mine.activity.map(\.summary), ["new"])
    }

    func testStoredActivityIsTheLatestAndItsOutputIsShortened() {
        let local = (0 ..< 250).map { entry("\($0)", at: start.addingTimeInterval(Double($0)), tail: String(repeating: "x", count: 2000)) }
        let combined = SyncActivity.combine(local: local, remote: [], clearedAt: nil)
        XCTAssertEqual(combined.entries.count, SyncActivity.limit)
        XCTAssertEqual(combined.entries.first?.summary, "50")
        XCTAssertEqual(combined.entries.last?.results.first?.tail.count, SyncActivity.tailLimit)
    }

    func testADocumentFromBeforeTheseKindsStillReads() throws {
        let old = #"{"identities":{},"machines":{}}"#
        let document = try JSONDecoder().decode(SyncDocument.self, from: Data(old.utf8))
        XCTAssertTrue(document.snippets.isEmpty)
        XCTAssertTrue(document.activity.isEmpty)
        let state = try JSONDecoder().decode(SyncState.self, from: Data(old.utf8))
        XCTAssertTrue(state.knownHosts.isEmpty)
    }

    func testAnUnchangedRoundUploadsNothing() {
        var cloud: Data?
        var mine = Device()
        mine.snippets = [RDSnippet(name: "a")]
        mine.activity = [entry("a", at: start)]
        mine.sync(&cloud, at: start.addingTimeInterval(1))
        let stored = cloud
        mine.sync(&cloud, at: start.addingTimeInterval(2))
        XCTAssertEqual(cloud, stored)
    }
}
