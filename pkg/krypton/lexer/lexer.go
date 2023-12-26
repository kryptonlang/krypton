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
	"bufio"
	"errors"
	"fmt"
	"io"
	"unicode/utf8"

	"laptudirm.com/x/krypton/pkg/krypton/file"
	"laptudirm.com/x/krypton/pkg/krypton/token"
)

func Lex(source io.Reader, handler ErrorHandler) *Lexer {
	lexer := Lexer{
		// convert the given io.Reader into a bufio.Reader
		source: bufio.NewReader(source),

		// make the channel where the tokens will be sent
		tokenStream: make(chan token.Token),

		errorHandler: handler,

		// both position pointers start at origin
		tokenStart: file.Origin,
		tokenEnd:   file.Origin,
	}

	// read a rune into current before proceeding
	lexer.current = lexer.readRune(true)

	go lexer.lex() // concurrently lex
	return &lexer
}

type Lexer struct {
	// information about the source that is being lexed
	source  *bufio.Reader // the source
	current rune          // current rune in source

	tokenStream chan token.Token // token stream channel
	closed      bool             // is the token stream is closed

	// lexing errors
	Errors       int
	errorHandler ErrorHandler

	// if the previous token was a token after which a
	// semicolon should be inserted after a newline
	insertSemi bool

	// current token position information
	tokenStart file.Pos // token start position
	tokenEnd   file.Pos // token end position

	tokenLiteral string // current token's string literal
}

func (lexer *Lexer) NextToken() token.Token {
	if lexer.closed {
		return token.Token{
			Type:    token.EOF,
			Literal: "",
			Pos:     lexer.tokenStart,
		}
	}

	return <-lexer.tokenStream
}

func (lexer *Lexer) HasErrors() bool {
	return lexer.Errors > 0
}

// some useful rune constants
const (
	eof = -1     // eof is the rune representing the end of the file
	bom = 0xFEFF // bom is the rune representing the byte order mark
)

// emit emits the current token as a Token of the given TokenType.
func (lexer *Lexer) emit(tokenType token.Type) {
	// comments don't influence semicolon insertion decisions
	if tokenType != token.Comment {
		lexer.insertSemi = tokenType.InsertSemiAfter()
	}

	// emit the token and discard it
	lexer.tokenStream <- token.Token{
		Type:    tokenType,
		Literal: lexer.tokenLiteral,
		Pos:     lexer.tokenStart,
	}
	lexer.discard()
}

// discard discards the token that is currently being lexed.
func (lexer *Lexer) discard() {
	lexer.tokenLiteral = ""           // discard the string literal
	lexer.tokenStart = lexer.tokenEnd // close the position window
}

// consume consumes the current rune, adding it to the current token.
func (lexer *Lexer) consume() {
	// add the rune to the current token
	lexer.tokenLiteral += string(lexer.current)

	// move the token's end position marker
	lexer.tokenEnd.NextCharacter()
	if lexer.current == '\n' {
		// current character is a newline, so move to next line
		lexer.tokenEnd.NextLine()
	}

	// read the next rune
	lexer.current = lexer.readRune(false)
}

var ErrIllegalBOM = fmt.Errorf("unexpected byte order mark")
var ErrIllegalUTF8 = fmt.Errorf("illegal utf-8 encountered")

// readRune reads the next rune from the source.
func (lexer *Lexer) readRune(first bool) rune {
	if lexer.closed {
		return eof
	}

	for {
		// read the next rune from the source
		switch char, size, err := lexer.source.ReadRune(); {
		// successfully read rune; return
		default:
			// return the new rune
			return char

		// Handle various errors from read operation.

		// End Of File reached, set rune to eof marker
		case errors.Is(err, io.EOF):
			return eof

		// invalid utf-8 encoding found in source
		case char == utf8.RuneError && size == 1:
			lexer.raise(ErrIllegalUTF8)

		// out-of-place byte order mark found in source
		case char == bom:
			// Byte Order Mark is only legal as the first rune, in which
			// case discard the rune and read a new rune from the source.
			if !first {
				lexer.raise(ErrIllegalBOM)
			}

			// Even if it was previously the first rune it no longer is.
			first = false

		// WideError encountered while reading rune; fatal.
		case err != nil:
			lexer.raise(err)

			// fatal error
			lexer.close()
			return eof
		}

		// WideError encountered: try again
	}
}

func (lexer *Lexer) raise(err error) {
	lexer.raiseAt(lexer.tokenEnd, err)
}

func (lexer *Lexer) raiseAtTop(err error) {
	lexer.raiseAt(lexer.tokenStart, err)
}

func (lexer *Lexer) raiseAt(pos file.Pos, err error) {
	lexer.Errors++
	lexer.errorHandler(&Error{pos, err})
}

func (lexer *Lexer) close() {
	if !lexer.closed {
		lexer.current = eof
		close(lexer.tokenStream)
		lexer.closed = true
	}
}
