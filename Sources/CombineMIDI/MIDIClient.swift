import CoreMIDI

/// Object holding a reference to a low-level CoreMIDI client
/// when it is in memory.
public final class MIDIClient {
    private(set) var client = MIDIClientRef()
    private(set) var ports = Set<MIDIClientRef>()
    private let name: String

    /// Initializes the client with a supplied name.
    /// - Parameter name: Name of the client, "Combine Client" by default.
    public init(name: String = "Combine Client") {
        self.name = name
        MIDIClientCreateWithBlock(name as CFString, &client) { [weak self] notification in
            self?.receiveMIDINotification(notification: notification)
        }
    }

    deinit {
        MIDIClientDispose(client)
    }
    
    /// Calls refreshConnections() when necessary, to ensure all sources are connected to all ports
    private func receiveMIDINotification(notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged:
            break
        case .msgObjectAdded:
            refreshConnections()
        case .msgObjectRemoved:
            break
        case .msgPropertyChanged:
            break
        case .msgThruConnectionsChanged:
            break
        case .msgSerialPortOwnerChanged:
            break
        case .msgIOError:
            break
        @unknown default:
            break
        }
    }
    
    /// Connects every single port to every single source
    public func refreshConnections() {
        for i in 0...MIDIGetNumberOfSources() {
            ports.forEach { port in MIDIPortConnectSource(port, MIDIGetSource(i), nil) }
        }
    }
    
    /// Returns new MIDI message publisher for this client.
    public func publisher() -> MIDIPublisher {
        MIDIPublisher(client: self)
    }
    
    /// Adds a port to the set of ports
    public func addPort(port: MIDIClientRef) {
        ports.insert(port)
    }
    
    /// Removes a port from the set of ports
    public func removePort(port: MIDIClientRef) {
        ports.remove(port)
    }
    
    #if swift(>=5.5.2)
    /// Creates a new asynchronous stream by automatically creating new
    /// MIDI port and connecting to all available sources.
    @available(macOS 10.15, iOS 13.0, *)
    public var stream: AsyncStream<MIDIMessage> {
        AsyncStream { continuation in
            let stream = MIDIStream(client: self) { message in
                continuation.yield(message)
            }
            continuation.onTermination = { @Sendable _ in
                stream.terminate()
            }
        }
    }
    #endif

    func generatePortName() -> String {
        "\(name)-\(UUID().uuidString)"
    }
}
