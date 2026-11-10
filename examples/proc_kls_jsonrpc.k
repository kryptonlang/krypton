// proc_kls_jsonrpc.k — smoke test for stdlib/proc.k.
//
// Spawns kls.exe (the Krypton Language Server), sends an LSP
// `initialize` request as JSON-RPC over stdin (with Content-Length
// framing), reads the response from stdout. Confirms the
// bidirectional pipe API works end-to-end against a real LSP server.

import "k:proc"

func makeFrame(body) {
    // LSP framing: Content-Length: N\r\n\r\n<body>
    let n = len(body)
    emit "Content-Length: " + n + "\r\n\r\n" + body
}

just run {
    // Initialize request — LSP spec calls this the very first message.
    let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"processId\":null,\"rootUri\":null,\"capabilities\":{}}}"
    let frame = makeFrame(body)

    print("spawning kls.exe")
    let p = procSpawn("kls.exe", "")
    if p == "0" {
        print("FAIL: procSpawn returned 0 (kls.exe not found on PATH?)")
        exit(1)
    }
    print("spawned, handle=" + p)

    print("alive=" + procAlive(p))

    print("writing initialize request (" + len(frame) + " bytes)")
    let w = procWrite(p, frame)
    print("write result=" + w)

    print("reading response...")
    let reply = procRead(p, 4096)
    print("got " + len(reply) + " bytes")
    print("---reply---")
    print(reply)
    print("---end reply---")

    print("closing")
    procClose(p)
    print("done")
}
