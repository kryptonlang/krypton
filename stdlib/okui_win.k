// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// stdlib/okui_win.k -- Windows OKUI wrapper.
//
// Choc is Windows backend. Obj-K is facade. okui_core is programmer-facing API.

module okui

import "head:user32"
import "head:dwmapi"
import "head:uxtheme"
import "head:comdlg32"
import "head:shell32"
import "k:gui"
import "k:shell"
import "k:choc"
import "k:objk_layout"
import "k:objk"
import "k:okui_core"
