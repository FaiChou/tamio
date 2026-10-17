//
//  AgentSocket.swift
//  TamioModule
//
//  Where MCP clients reach the server: a Unix socket in the app's
//  Application Support folder, mode 0600, that only the user's own processes
//  may use (checked with getpeereid). The tamio-mcp helper relays a client's
//  stdio to it; messages are JSON-RPC, one per line, as on MCP's stdio
//  transport.
//

import Darwin
import Foundation

public final class AgentSocket: @unchecked Sendable {
    public static let shared = AgentSocket()

    public static var path: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "sb.moe.tamio", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("agent.sock").path
    }

    private let lock = NSLock()
    private var listener: Int32 = -1
    private var clients: Set<Int32> = []

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return listener >= 0
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard listener < 0 else { return }
        let path = Self.path
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8.prefix(MemoryLayout.size(ofValue: address.sun_path) - 1))
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else {
            close(fd)
            return
        }
        listener = fd
        Thread.detachNewThread { [weak self] in self?.acceptLoop(fd) }
    }

    public func stop() {
        lock.lock()
        let fd = listener
        let open = clients
        listener = -1
        clients = []
        lock.unlock()
        if fd >= 0 {
            close(fd)
            unlink(Self.path)
        }
        for client in open { shutdown(client, SHUT_RDWR); close(client) }
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                return
            }
            // Only this user's processes; root and other users are turned away.
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
                close(client)
                continue
            }
            var noSigPipe: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            lock.lock()
            clients.insert(client)
            lock.unlock()
            Thread.detachNewThread { [weak self] in self?.serve(client) }
        }
    }

    private func serve(_ client: Int32) {
        let session = AgentSession()
        var pending = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        defer {
            lock.lock()
            clients.remove(client)
            lock.unlock()
            close(client)
        }
        while true {
            let count = read(client, &buffer, buffer.count)
            if count <= 0 { return }
            pending.append(buffer, count: count)
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = String(decoding: pending[pending.startIndex ..< newline], as: UTF8.self)
                pending.removeSubrange(pending.startIndex ... newline)
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                // Each request runs on its own: a run waiting for approval
                // does not hold up a ping or a list.
                Task { @MainActor in
                    guard let reply = await AgentServer.shared.handle(line, client: session) else { return }
                    let data = Array((reply + "\n").utf8)
                    data.withUnsafeBytes { raw in
                        var offset = 0
                        while offset < raw.count {
                            let written = write(client, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                            if written <= 0 { return }
                            offset += written
                        }
                    }
                }
            }
        }
    }
}
