// Copyright © 2023 Rak Laptudirm <rak@laptudirm.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package lexer

import (
	"fmt"

	"laptudirm.com/x/krypton/pkg/krypton/file"
)

// ErrorHandler is the function which handles the errors which the lexer
// encounters while lexing a source.
type ErrorHandler func(*Error)

// IgnoreErrors is a ErrorHandler which ignores all the errors.
func IgnoreErrors(*Error) {}

// Ensure IgnoreErrors is a ErrorHandler.
var _ ErrorHandler = IgnoreErrors

type Error struct {
	pos file.Pos
	err error
}

func (err *Error) Error() string {
	return fmt.Sprintf("%s: %s", &err.pos, err.err)
}

func (err *Error) Unwrap() error {
	return err.err
}
