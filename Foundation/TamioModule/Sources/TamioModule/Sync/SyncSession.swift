//
//  SyncSession.swift
//  TamioModule
//
//  One round of sync as a function: what this device has, what the store
//  holds, and out of them what to change here and what to upload. It touches
//  neither the store nor the app, so it runs off the main thread.
//

import Foundation

struct SyncInput: Sendable {
    var machines: [RDMachine]
    var identities: [RDIdentity]
    var state: SyncState
    var passphrase: String
    /// The stored envelope, if there is one.
    var remote: Data?
    /// A key derived earlier, to save deriving it again.
    var key: SyncCipher.Key?
    var syncsMachines = true
    var syncsIdentities = true
    /// Seal under a new key from `passphrase`, whatever is stored. What is
    /// stored is merged first if `key`, the one in use until now, still opens
    /// it; otherwise this device's data takes its place.
    var replacesRemote = false
    var now = Date()
    var rounds = SyncCipher.rounds
    var minimumRounds = SyncCipher.minimumRounds
}

enum SyncOutcome: Sendable {
    case done(Done)
    /// The passphrase does not open what is stored.
    case locked
    /// What is stored is not something this version wrote.
    case unreadable
    /// What is stored was written by a later version.
    case newer

    struct Done: Sendable {
        var machines: [SyncChange<RDMachine>]
        var identities: [SyncChange<RDIdentity>]
        var state: SyncState
        var key: SyncCipher.Key
        /// The envelope to store, when it changed.
        var upload: Data?
    }
}

enum SyncSession {
    static func run(_ input: SyncInput) -> SyncOutcome {
        var document = SyncDocument()
        var key = input.replacesRemote ? nil : input.key
        var stored = false

        if input.replacesRemote {
            if let remote = input.remote, let old = input.key,
               let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: remote),
               envelope.version == SyncEnvelope.currentVersion,
               envelope.salt == old.salt, envelope.rounds == old.rounds,
               let plain = try? SyncCipher.open(envelope, with: old),
               let decoded = try? JSONDecoder().decode(SyncDocument.self, from: plain)
            {
                document = decoded
            }
        } else if let remote = input.remote {
            guard let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: remote) else {
                return .unreadable
            }
            guard envelope.version <= SyncEnvelope.currentVersion else { return .newer }
            guard (input.minimumRounds ... SyncCipher.maximumRounds).contains(envelope.rounds),
                  envelope.salt.count >= 8
            else { return .unreadable }
            if key?.salt != envelope.salt || key?.rounds != envelope.rounds {
                key = SyncCipher.key(passphrase: input.passphrase, salt: envelope.salt, rounds: envelope.rounds)
            }
            guard let key else { return .locked }
            let plain: Data
            do {
                plain = try SyncCipher.open(envelope, with: key)
            } catch SyncCipher.OpenError.wrongPassphrase {
                return .locked
            } catch {
                // Damaged data is not a wrong passphrase: asking for another
                // one would not help.
                return .unreadable
            }
            guard let decoded = try? JSONDecoder().decode(SyncDocument.self, from: plain) else {
                return .unreadable
            }
            document = decoded
            stored = true
        }

        let sealing = key ?? SyncCipher.key(
            passphrase: input.passphrase, salt: SyncCipher.newSalt(), rounds: input.rounds
        )
        var state = input.state
        var dirty = !stored
        var machineChanges: [SyncChange<RDMachine>] = []
        var identityChanges: [SyncChange<RDIdentity>] = []

        // A kind that is not synced here is passed on as it was stored.
        if input.syncsMachines {
            let merged = SyncMerge.reconcile(
                local: input.machines, state: &state.machines, remote: document.machines, now: input.now
            )
            document.machines = merged.entries
            machineChanges = merged.changes
            dirty = dirty || merged.dirty
        }
        if input.syncsIdentities {
            let merged = SyncMerge.reconcile(
                local: input.identities, state: &state.identities, remote: document.identities, now: input.now
            )
            document.identities = merged.entries
            identityChanges = merged.changes
            dirty = dirty || merged.dirty
        }

        var upload: Data?
        if dirty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let plain = try? encoder.encode(document),
                  let sealed = try? SyncCipher.seal(plain, with: sealing)
            else { return .unreadable }
            upload = sealed
        }
        return .done(.init(
            machines: machineChanges, identities: identityChanges, state: state, key: sealing, upload: upload
        ))
    }
}
