# kls — Krypton Language Server

Self-hosted LSP 3.17 server for Krypton (`.k` files), written in Krypton with
platform-specific stdio framing. Native builds are the target; the checked-in
Windows wrapper remains a legacy fallback until native Windows validation is
complete.

## Status

Current version: **0.2.0**.

| Capability                        | Wired |
|-----------------------------------|-------|
| `textDocumentSync` (Full)         | ✅ |
| `publishDiagnostics`              | ✅ — tokenizer + structural validator |
| `documentSymbolProvider`          | ✅ — top-level `func`/`fn`/`callback`/`struct`/`module`/`const`/`let` |
| `completionProvider`              | ✅ — keywords + 109 builtins + open-buffer functions |
| `hoverProvider`                   | ⏳ session 4 |
| `definitionProvider`              | ⏳ session 4 |
| `referencesProvider`              | ⏳ session 5 |
| `signatureHelpProvider`           | ⏳ session 5 |
| `renameProvider`                  | ⏳ later |
| `documentFormattingProvider`      | ⏳ later |

## Diagnostics produced

**Tokenizer ([lex.k](lex.k)) — severity 1 (error):**

- `unterminated string literal`
- `unterminated block comment`
- `unterminated backtick string`
- `hex literal needs digits`

**Validator ([validate.k](validate.k)) — severity 1 (error) or 2 (warning):**

- `stray '<X>' with no matching opener`
- `mismatched '<X>' — expected '<Y>' to close '<Z>' at line N`
- `unterminated '<X>' (no matching closer)`
- `'func' must be followed by a function name`
- `function 'X' missing '(' for parameter list`
- `'let' must be followed by a variable name`
- `duplicate function name 'X'` (warning only)

## Architecture

```
┌────────────┐                  ┌────────────────────────────────┐
│  editor    │   stdio frames   │  kls.exe                       │
│  (LSP      │ ───────────────▶ │  ┌──────────────────────────┐  │
│   client)  │ ◀─────────────── │  │ jsonrpc.k (cfunc framing)│  │
└────────────┘                  │  └────────────┬─────────────┘  │
                                │  ┌────────────▼─────────────┐  │
                                │  │ json_parse.k             │  │
                                │  │  → flat dot-path map     │  │
                                │  └────────────┬─────────────┘  │
                                │  ┌────────────▼─────────────┐  │
                                │  │ kls.k method dispatch    │  │
                                │  └─┬────┬────┬────┬──────────  │
                                │    │    │    │    │             │
                                │    ▼    ▼    ▼    ▼             │
                                │   lex validate symbols complete │
                                │    │    │    │    │             │
                                │    └────┴────┴────┘             │
                                │            │                    │
                                │  ┌─────────▼──────────────────┐ │
                                │  │ json_emit.k                │ │
                                │  │  → response JSON           │ │
                                │  └────────────────────────────┘ │
                                └────────────────────────────────┘
```

## Files

| File | LOC | Purpose |
|------|----:|---------|
| [lex.k](lex.k)             | ~225 | Position-aware tokenizer + lex diagnostics |
| [validate.k](validate.k)   | ~210 | Bracket/paren balance + parse-shape checks |
| [symbols.k](symbols.k)     | ~85  | Token walk → DocumentSymbol JSON |
| [complete.k](complete.k)   | ~110 | Keywords + builtins + buffer funcs |
| [json_parse.k](json_parse.k) | ~470 | Recursive JSON → flat dot-path map (custom `\x03`/`\x04` separators) |
| [json_emit.k](json_emit.k) | ~135 | Nested JSON builder (jeStr/jeNum/jeObj/jeArr/jeDiagnostic/jeRange) |
| [jsonrpc.k](jsonrpc.k)     | ~115 | Content-Length framed stdio (cfunc — `_setmode(_O_BINARY)` defeats CRLF mangling) |
| [kls.k](kls.k)             | ~245 | Main loop, dispatch, document table |
| [build.bat](build.bat)     | —    | Windows build wrapper |
| [test_kls.py](test_kls.py) | —    | Smoke driver (pipes framed requests, prints framed responses) |

## Build

```bat
lsp\build.bat
```

The intended native commands are:

```sh
KRYPTON_ROOT=/absolute/path/to/krypton kcc lsp/kls.k -o lsp/kls
```

```bat
kcc lsp\kls.k -o kls.exe
```

The current Windows wrapper may still use its legacy fallback until native
Windows stdio and Win32 argument handling are verified. Do not commit generated
`_kls.c` files.

Requires the matching Krypton compiler and `KRYPTON_ROOT` pointing to the same
checkout or installation. Do not mix a stale frontend binary with current
`compile.k`; it can report false syntax errors in valid `just run` programs.

## Smoke test

```bat
python lsp\test_kls.py
```

Pipes a sequence of LSP requests at `kls.exe` and prints responses. Verifies
diagnostics, documentSymbol, completion end-to-end.

## Wiring to an editor

`kls.exe` reads JSON-RPC frames from stdin and writes them to stdout. Any
LSP-aware editor can launch it.

### Helix (`languages.toml`)

```toml
[[language]]
name = "krypton"
scope = "source.krypton"
file-types = ["k"]
language-server = { command = "C:/path/to/kls.exe" }
roots = []
```

### Neovim (with `nvim-lspconfig` or raw `vim.lsp.start`)

```lua
vim.lsp.start({
  name = "kls",
  cmd = { "C:/path/to/kls.exe" },
  filetypes = { "krypton" },
  root_dir = vim.fn.getcwd(),
})
```

### VS Code

The [krypton-lang](../krypton-lang/) extension (1.8.1+) bundles `kls.exe`
and a hand-rolled JSON-RPC client (no `vscode-languageclient`
dependency, so the .vsix stays tiny — 181 KB). Install:

```bash
code --install-extension extensions/krypton-language-1.8.1.vsix
```

Configuration:

```json
{
  "krypton.kls.path": "",       // empty = use bundled binary
  "krypton.kls.enabled": true,  // false = syntax-only mode
  "krypton.kls.trace": false    // true = log every frame
}
```

## Known caveats

- **Windows-only build** — the `cfunc` block in [jsonrpc.k](jsonrpc.k) uses
  `_setmode(_O_BINARY)` and `_strnicmp`, both Windows CRT. POSIX port
  swaps these for `setvbuf` / `strncasecmp` / no setmode.
- **Full sync only** — no incremental `didChange` (`contentChanges` is
  expected to be a single full-buffer entry).
- **Tokenizer/structural diagnostics only** — semantic errors (undefined
  variables, wrong arity) wait for a real type checker.
- **Position-insensitive completion** — same set returned regardless of
  cursor position. Context-aware filtering is session 3+.
- **No incremental re-parse** — every `didChange` re-tokenises the whole
  buffer. Fine up to ~10K lines; revisit when needed.
