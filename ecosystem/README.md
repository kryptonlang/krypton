# ecosystem/ — proprietary lane

| Path | License | Contents |
| ---- | ------- | -------- |
| `ecosystem/smackui/` | Karpl Proprietary License | reserved SmackUI commercial components |
| `ecosystem/priv/` | Karpl Proprietary License | private product work; never released |
| rest of repository | Apache-2.0 (`LICENSE`) | Krypton compiler, toolchain, stdlib |

Dual-license intent: the Krypton core (`compiler/`, `stdlib/`, `headers/`,
`kr`, `docs/`) is Apache-2.0. This directory holds the proprietary
extensions that are not Apache-2.0 and never will be. There is no implicit
license for files under `ecosystem/`; see `LICENSE-PROPRIETARY`.

In-tree SmackUI under `stdlib/smack/` is Apache-2.0 today. Any move to this
directory is a deliberate, separately-reviewed relicense, not a silent one.
