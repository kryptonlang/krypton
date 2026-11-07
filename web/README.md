# Krypton Web (`kweb`)

`web/` is Krypton's web framework area. It lets you write pages in Krypton,
build static HTML into `dist/`, preview locally, and deploy the generated files.

The short version:

```text
.htk source
  -> Krypton compiler / kweb
  -> generated HTML files in dist/
  -> upload dist/ to web host
```

No C or Objective-C source is part of this workflow.

## What Is `.htk`?

`.htk` means "HTML template written in Krypton".

An `.htk` file is normal Krypton source with a web convention:

- import `k:htmk`
- write functions that return HTML strings
- use `htPage`, `htDiv`, `htP`, `htA`, `htStyle`, etc.
- for static sites, write final files into `dist/`
- for live demos, respond to HTTP requests

Example shape:

```krypton
import "k:htmk"

func homePage() {
    emit htPage("Hello", "",
        htMain(
            htH1("Hello from Krypton") +
            htP("This HTML was built by Krypton.")
        )
    )
}

just run {
    writeFile("dist/index.html", homePage())
}
```

That program builds a string of HTML and writes it as a real webpage.

## Main Pieces

### `k:htmk`

`stdlib/htmk.k` is the HTML builder library.

It gives helpers like:

- `htPage(title, head, body)`
- `htH1(text)`
- `htP(text)`
- `htA(href, text)`
- `htDiv(content)`
- `htDivA(attrs, content)`
- `htStyle(css)`
- `htMetaViewport()`

These helpers return strings. You combine them with `+`.

### `site.htk`

`site.htk` usually contains page functions and shared layout.

For example:

- shared CSS
- nav bar
- footer
- `pageHome()`
- `pageAbout()`
- `pageContact()`

Think of `site.htk` as the source of the website.

### `export.htk`

`export.htk` is the static-site generator.

It imports or defines the page functions, then writes files:

```krypton
just run {
    writeFile("dist/index.html", pageHome())
    writeFile("dist/about.html", pageAbout())
}
```

Think of `export.htk` as the build script for the site.

### `dist/`

`dist/` is generated output.

It contains files your host serves:

- `index.html`
- `about.html`
- CSS/JS/assets if your site writes or copies them
- `.htaccess` when using Apache-style clean URLs/security headers

`dist/` is the folder that gets deployed.

## `kweb` Commands

`web/kweb` is the existing kweb binary.

From inside a project folder:

```bash
kweb build
```

Builds `dist/` by compiling/running `export.htk`.

```bash
kweb serve 8080
```

Serves `dist/` locally for preview.

The 2.4.9 macOS CLI uses `k:server_native` (no C compiler). Preview supports
binary assets, rejects traversal and symlinks, and reports bind/port errors.
It binds all interfaces: development use only, on a trusted network. Do not
expose it as a production server. This preview change is not a Windows release.
`kweb build` now fails when the exporter exits unsuccessfully.

```bash
kweb deploy example.com username
```

Uploads `dist/` recursively by FTP. The default remote target is the FTP login
root. For hosts like Hostinger where the FTP account already starts inside
`public_html`, do not add `public_html/`.

Blank, `.`, `./`, `""`, and `''` remote-directory values are all normalized to
the FTP login root. KWeb rejects quote-bearing and parent-traversal paths rather
than creating accidental remote folders.

To deploy into a folder under the login root:

```bash
kweb deploy example.com username test
```

That uploads `dist/index.html` to `test/index.html`.

For non-interactive deploys, a fourth argument can pass the FTP password:

```bash
kweb deploy example.com username test your-password
```

To pass a password while still targeting the FTP login root, use `.` as the
remote-directory placeholder:

```bash
kweb deploy example.com username . your-password
```

KWeb stops at the first failed upload and exits nonzero instead of reporting a
successful deployment after curl fails.

The Windows and macOS GUIs use FTP directly and have fields for host, user,
password, and an optional remote folder.

## Creating A New Site

```bash
web/kweb init mysite
cd mysite
../web/kweb build
../web/kweb serve 8080
```

Generated shape:

```text
mysite/
  site.htk
  export.htk
  dist/
    .htaccess
```

Edit `site.htk`, then run `kweb build` again.

## Current Repo Site

`web/site/` is the source for the Krypton website.

Important files:

- `web/site/site.htk` - page/layout source
- `web/site/export.htk` - static export builder
- `web/site/dist/` - generated website output

The usual flow:

```bash
cd web/site
../kweb build
../kweb serve 8080
../kweb deploy example.com username
```

## Live Web Apps vs Static Export

Krypton web code has two common modes.

### Static Export

Best for normal websites.

The `.htk` program writes HTML files into `dist/`. Host serves plain files.

Use this for:

- docs
- landing pages
- blogs
- project sites
- pages deployed by FTP/SFTP

### Live Server

Best for demos and local tools.

The `.htk` program handles requests and responds dynamically.

Examples live in `web/examples/`:

- `hello.htk`
- `form.htk`
- `router.htk`
- `interactive.htk`
- `features.htk`

## Objective-K GUI

`web/kweb_gui.ks` is the native macOS GUI wrapper for kweb.

It is KryptScript compiled by `kcc`, using `k:okui`, the app-facing
Objective-K layer. `okui` routes to the macOS Choc/AppKit backend here and to
Forge's Windows Choc/Win32 backend on Windows.

### Building The App Bundle

```bash
bootstrap/kcc_driver_macos_aarch64 -r scripts/build-objk-app.ks web/kweb_gui.ks kweb
```

Output:

```text
dist/kweb.app
```

`KRYPTON_ROOT` must be set in the shell that builds it: for `kweb` the script
refuses to run without it, then embeds the driver, seed compiler, `stdlib/`, and
`headers/` under `Contents/Resources` so the bundle is self-contained.

OKUI smoke app:

```bash
bootstrap/kcc_driver_macos_aarch64 -r scripts/build-objk-app.ks examples/objk/human_ui.ks human_ui
```

## Operating The kweb App

The window is titled `kweb deploy` and has six fields, four buttons, a status
line, and a log pane.

### Launch

```bash
open dist/kweb.app
```

Or double-click `kweb.app` in Finder. There is no project argument: the app
opens with **Project** set to its own working directory, so either start it from
the project you want or press **Choose** and pick the folder. Launched from
Finder the working directory is often `/`, so **Project** will need changing
before **Build** or **Deploy** will do anything.

### Fields

| Field | Meaning |
| --- | --- |
| **Project** | Project root. **Build** runs here; **Deploy** uploads `<project>/dist`. **Choose** opens a folder picker. |
| **kweb** | Path to the `kweb` CLI. Prefilled with the first that exists: the app's bundled `kweb-cli`, `<cwd>/web/kweb`, `/usr/local/krypton/web/kweb`, this checkout's `web/kweb`, then bare `web/kweb`. Override it if the CLI lives elsewhere. |
| **Host** | FTP host name. `ftp://` and `sftp://` prefixes and trailing slashes are stripped; the transport is always plain FTP. |
| **User** / **Pass** | FTP credentials. The password is masked. |
| **Remote dir** | Optional folder under the FTP login root. Blank, `.`, `./`, `""` and `''` all mean the login root; leading and trailing slashes are trimmed. Quote characters and `..` are rejected with a dialog. |

Every button validates only what it needs and shows a dialog rather than running
with an empty path or missing credentials. **Project** and **kweb** must both be
set for **Build**; **Deploy** also needs **Host**, **User**, and **Pass**.

### Buttons

- **Build** — runs `kweb build` in **Project** and appends the echoed command and
  its combined output to the log. The status line goes to `Build running`, then
  `Build finished` or `Build failed`; a failure also raises a dialog. The output
  is written to a temp file and read back after the command exits, so it appears
  in one block, not live.
- **Deploy** — uploads `<project>/dist` to **Host** as **User**. See below.
- **Open dist** — `open <project>/dist` in Finder, to inspect the build before
  publishing.
- **Clear** — empties the log and sets the status line back to `Ready`.

When the app runs as a bundle it points `KRYPTON_ROOT` at its own embedded
toolchain, which is what lets `k:htmk` imports resolve without an installed
Krypton. Run from source without that payload and **Build** uses whatever
`kweb` resolves to on `PATH` or in the field.

### What Deploy Uploads

Only the contents of `<project>/dist`, discovered by a recursive walk. Build
first: an empty or missing `dist/` logs `No files found in dist/` and stops.

Relative paths are preserved under the remote folder:

- empty remote folder: `dist/index.html` uploads to `index.html`
- `pages`: `dist/index.html` uploads to `pages/index.html`
- `sites/krypton`: `dist/index.html` uploads to `sites/krypton/index.html`

Files go up in batches of ten over one reusable curl connection per batch, with
`--ftp-create-dirs`, a 15-second connect timeout, 120 seconds per transfer, and
five retries. That batching is what keeps hosts with connection limits from
refusing a site-wide upload.

The first failed batch stops the run, logs `Deploy failed (curl exit N)`, and
leaves later files untouched. Pressing **Deploy** again restarts from the first
file, so re-running is safe but not resumable.

Do not enter `public_html` for Hostinger-style FTP accounts that already log in
inside the website root; that nests the site one level too deep.

### Caveats

- Deploy is FTP with `--insecure`: credentials and file contents cross the
  network unencrypted. Use it for throwaway hosting; SFTP is not wired up here.
- The password is passed to curl as an argument, so it is briefly visible in the
  process list while a batch runs.
- The app builds and deploys. It does not run `kweb serve`; preview is still the
  CLI step above (`../kweb serve 8080` from the project folder).
- Text, field, and log colors follow the system light/dark appearance; there is
  no in-app toggle.

## Mental Model

When writing a static Krypton website:

1. Write HTML-producing functions in `.htk`.
2. Keep shared layout in functions.
3. Make one function per page.
4. In `export.htk`, call those page functions.
5. Write each result into `dist/*.html`.
6. Preview `dist/`.
7. Deploy `dist/`.

The page is "converted" because Krypton runs your page functions and the final
strings they emit are saved as `.html` files.
