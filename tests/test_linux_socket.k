// Linux native IPv4 socket smoke test: listen/connect/accept/send/recv.
just run {
    let server = sockMake()
    if server < 0 { print("[FAIL] sockMake server")  exit(1) }
    if sockBind(server, 85, 102) != 0 { print("[FAIL] sockBind")  exit(1) }
    if sockListen(server, 1) != 0 { print("[FAIL] sockListen")  exit(1) }
    let client = sockMake()
    if client < 0 { print("[FAIL] sockMake client")  exit(1) }
    if sockConnect(client, 127, 0, 0, 1, 85, 102) != 0 { print("[FAIL] sockConnect")  exit(1) }
    let peer = sockAccept(server)
    if peer < 0 { print("[FAIL] sockAccept")  exit(1) }
    if sockSend(client, "ping", 4) != 4 { print("[FAIL] sockSend")  exit(1) }
    let text = sockRecvStr(peer)
    if text != "ping" { print("[FAIL] sockRecvStr")  exit(1) }
    if sockSend(client, "pong", 4) != 4 { print("[FAIL] sockSend second")  exit(1) }
    let buf = bufNew(4)
    if sockRecv(peer, buf, 4) != 4 { print("[FAIL] sockRecv")  exit(1) }
    if bufGetByte(buf, 0) != 112 || bufGetByte(buf, 3) != 103 { print("[FAIL] socket payload")  exit(1) }
    sockSend(peer, "pong", 4)
    sockRecv(client, buf, 4)
    if bufGetByte(buf, 0) != 112 || bufGetByte(buf, 3) != 103 { print("[FAIL] socket reply")  exit(1) }
    sockSend(client, "raw!", 4)
    if fdReadN(peer, buf, 4) != 4 { print("[FAIL] fdReadN")  exit(1) }
    if bufGetByte(buf, 0) != 114 || bufGetByte(buf, 3) != 33 { print("[FAIL] fdReadN payload")  exit(1) }
    let passfd = memfdCreate(16)
    if sockSendFd(client, "x", 1, passfd) != 1 { print("[FAIL] sockSendFd")  exit(1) }
    fdClose(passfd)
    sockClose(peer)
    sockClose(client)
    sockClose(server)
    print("[PASS] Linux sockets")
}
