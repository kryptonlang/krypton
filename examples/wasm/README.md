# WebAssembly Binary-Writing Example

`hello_wasm.htk` is the original 2026-05-30 proof that Krypton can write a valid
WebAssembly binary. It manually assembles a 95-byte module, rather than lowering
Krypton IR. The production backend is
[`compiler/wasm32/wasm_self.k`](../../compiler/wasm32/wasm_self.k).
This example is not required by the normal compiler build.

## Build And Run

From the repository root with the current Krypton compiler installed:

```sh
kcc -r examples/wasm/hello_wasm.htk /tmp/hello.wasm
xxd /tmp/hello.wasm
```

Or use the macOS checkout driver directly:

```sh
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 \
  -r examples/wasm/hello_wasm.htk /tmp/hello.wasm
```

The optional argument selects the output file; without it, the example writes
`hello.wasm` in the current directory. No C/Objective-C source, Clang, GCC or
external linker is involved.

## Verify With Node.js

The module exports `memory` and `_start` and imports `env.console_log(ptr,len)`.
It is not a WASI module; the host must provide that import.

```sh
node - /tmp/hello.wasm <<'JS'
const fs = require('node:fs');
(async () => {
  const bytes = fs.readFileSync(process.argv[2]);
  if (bytes.length !== 95 || !WebAssembly.validate(bytes)) throw new Error('invalid proof');
  let instance;
  let output = '';
  ({ instance } = await WebAssembly.instantiate(bytes, {
    env: { console_log(ptr, len) {
      output += Buffer.from(instance.exports.memory.buffer, ptr, len).toString('utf8');
    } }
  }));
  instance.exports._start();
  if (output !== 'Hello') throw new Error('unexpected output: ' + output);
  console.log(output);
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
```

Expected output: `Hello`.

## Binary-Format Findings

- Ordinary Krypton text is NUL-terminated. Concatenating `fromCharCode(0)` is
  not a binary-safe way to assemble a WASM module.
- This example uses `writeBytes(path,hexString)`, encoding every byte as `xHH`.
- String indexing returns a one-character string. `charCode(s[i])` obtains its
  byte value; `toInt(s[i])` would instead parse it as decimal text.

See the [WASM design notes](../../docs/wasm_backend_design.md) for the historical
section layout and IR-lowering design.
