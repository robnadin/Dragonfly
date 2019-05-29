import DragonflyCore
import NIO
import NIOExtras

public final class DragonflyServer {
    static let packetHandler = PacketHandler()
    static let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    static var bootstrap =  {
        ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        // Set the handlers that are applied to the accepted Channels
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(DebugInboundEventsHandler(), name: "DebugInbound1").flatMap { _ in
                channel.pipeline.addHandler(ByteToMessageHandler(PacketDecoder()), name: "PacketDecoder")
                }.flatMap { _ in
                    channel.pipeline.addHandler(DebugInboundEventsHandler(), name: "DebugInbound2")
                }.flatMap { _ in
                    channel.pipeline.addHandler(DebugOutboundEventsHandler(), name: "DebugOutbound3")
                }.flatMap { _ in
                    channel.pipeline.addHandler(MessageToByteHandler(PacketEncoder()), name: "PacketEncoder")
                }.flatMap { _ in
                    channel.pipeline.addHandler(DebugOutboundEventsHandler(), name: "DebugOutbound2")
                }.flatMap { _ in
                    channel.pipeline.addHandler(DragonflyServer.packetHandler, name: "SharedPacketHandler")
                }.flatMap { _ in
                    channel.pipeline.addHandler(DebugOutboundEventsHandler(), name: "DebugOutbound1")
            }
        }
        // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
        .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    }()
    
    
    public static func run() {
        defer { try! group.syncShutdownGracefully() }
        
        let defaultHost = "::1"
        let defaultPort = 9999
        let channel = try! bootstrap.bind(host: defaultHost, port: defaultPort).wait()
        
        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        print("Server started and listening on \(localAddress)")
        
        try! channel.closeFuture.wait()
        
        print("DragonflyServer closed")
    }
}