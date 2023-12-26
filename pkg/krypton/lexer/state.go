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
	"strconv"
	"unicode"
	"unicode/utf8"

	"laptudirm.com/x/krypton/pkg/krypton/token"
)

func (lexer *Lexer) lex() {
lexing: // The main lexing loop.
	for {
		switch {
		// Runes in the unicode class lexer can start an identifier.
		case unicode.IsLetter(lexer.current):
			lexer.lexIdentifier()
		// Only the anonymous identifier starts with an underscore.
		case lexer.current == '_':
			lexer.consume()
			lexer.emit(token.Underscore)
		// Escaped identifiers start with a '\\'.
		case lexer.current == '\\':
			lexer.consume()           // leading \
			lexer.consumeIdentifier() // escaped identifier
			lexer.consume()           // trailing \
			lexer.emit(token.Identifier)

		// The decimal digits 0-9 start numbers.
		case unicode.IsDigit(lexer.current):
			lexer.lexNumber()

		// Rune literals start with single quotes.
		case lexer.current == '\'':
			lexer.lexRune()

		// Strings start with double quotes.
		case lexer.current == '"':
			lexer.lexString()

		// Every rune that starts an operator is itself an operator.
		case token.IsOperator(string(lexer.current)):
			lexer.lexOperator()

		// The rune '#' signals the start to a line comment.
		case lexer.current == '#':
			lexer.lexComment()

		// Newlines can be whitespace or statement terminators (semicolons).
		// If the last token was such that it could have been the final token
		// in a statement, a semicolon is inserted.
		case lexer.current == '\n':
			if lexer.insertSemi {
				lexer.emit(token.Semicolon) // automatic semicolon insertion
				continue lexing             // literally continue lexing :)
			}

			// Fallthrough into the whitespace case.
			fallthrough

		// Discard all whitespace, special cases have been handled above.
		case unicode.IsSpace(lexer.current):
			lexer.discardWhitespace()

		// End Of File reached, close the token stream and exit.
		case lexer.current == eof:
			lexer.close() // no more tokens will be sent
			break lexing  // no more lexing will be done

		// Illegal rune encountered, let the parser handle it.
		default:
			lexer.raise(fmt.Errorf("unexpected rune %q in source", lexer.current))
			// consume and discard illegal rune to prevent infinite loops
			lexer.consume()
			lexer.emit(token.Illegal)
		}
	}
}

// discardWhitespace consumes all the adjacent whitespace and discards it.
func (lexer *Lexer) discardWhitespace() {
	// While the next rune is a whitespace rune, consume it.
	for unicode.IsSpace(lexer.current) {
		lexer.consume()
	}

	// Discard all the consumed runes.
	lexer.discard()
}

// lexIdentifier consumes and emits an identifier/keyword token.
// lexIdentifier should only be called if the current rune is a letter,
// i.e. is a rune which belongs in the unicode category lexer (Letter).
func (lexer *Lexer) lexIdentifier() {
	// Consume the entire identifier.
	lexer.consumeIdentifier()
	// Emit either an Identifier or one of the keyword tokens.
	lexer.emit(token.Lookup(lexer.tokenLiteral))
}

func (lexer *Lexer) consumeIdentifier() {
	// Identifiers are composed of runes in the unicode categories lexer and Nd,
	// so while the next rune falls in one of those categories, consume it.
	for unicode.IsLetter(lexer.current) || unicode.IsDigit(lexer.current) || lexer.current == '_' {
		lexer.consume()
	}
}

// lexNumber consumes and emits a number token. lexNumber should only be
// called if the current rune is a decimal digit, i.e. is a rune which
// belongs in the unicode category Nd (Number, decimal) (0-9).
func (lexer *Lexer) lexNumber() {
	// Emit a token.Number once consumption is done.
	defer lexer.emit(token.Number)

	// Default base of the number is decimal (10).
	base := 10

	// cantBe0 represents whether the number literal
	// can't be a  standalone zero, i.e. just "0".
	cantBe0 := false
	if lexer.current == '0' {
		switch lexer.consume(); lexer.current {
		// Hexadecimal literal prefix.
		case 'x', 'X':
			base = 16

		// Octal literal prefix.
		case 'o', 'O':
			base = 8

		// Binary literal prefix.
		case 'b', 'B':
			base = 2

		// A lone zero is treated as an octal prefix.
		default:
			base = 8

			// No need to consume a missing prefix, so
			// directly go to lexing the base of the number.
			goto lexingNumberBase
		}

		cantBe0 = true  // A prefix was found so the literal can't be "0".
		lexer.consume() // Consume the prefix that was found.
	}

lexingNumberBase:
	// Only require digits if the number can't be a standalone 0, cause
	// otherwise it maybe a standalone 0 and doesn't require any more digits.
	lexer.consumeDigits(base, cantBe0)

	if base < 10 {
		// Exponents and floating points are not
		// supported for bases less than 10.
		return
	}

	// Check for a floating point and consume it if found.
	if lexer.current == '.' {
		lexer.consume() // Consume the floating point.
		lexer.consumeDigits(base, true)
	}

	// Check for an exponent on the literal.
	switch {
	case base == 16 && unicode.ToLower(lexer.current) == 'p',
		base == 10 && unicode.ToLower(lexer.current) == 'e':
		// Empty case to prevent switch into default, the lexing
		// is properly handled by code after this switch.

	case base == 10 && unicode.ToLower(lexer.current) == 'p':
		// Hexadecimal exponent indicator used inside a decimal literal,
		// warn the user but lex the rest of the number literal normally.
		lexer.raise(fmt.Errorf("hex exponent indicator %q in decimal literal, use 'e' instead", lexer.current))

	default:
		// No exponent found, consumption finished.
		return
	}

	lexer.consume() // Consume the exponent indicator.
	if lexer.current == '+' || lexer.current == '-' {
		// Consume the sign of the exponent.
		lexer.consume()
	}

	// Consume the exponent.
	lexer.consumeDigits(10, true)
}

// consumeDigits consumes as many digits of the given base as it can from
// the source. If the required flag is set, an error is raised if no digits
// of the given base can be consumed from the source.
func (lexer *Lexer) consumeDigits(base int, required bool) {
	if !token.IsDigit(lexer.current, base) && required {
		// The required flag is set but digits can't be consumed, so raise an error.
		lexer.raise(fmt.Errorf("expected digits of base %d, found %q", base, lexer.current))
	}

	// Consume the digits of the given base.
	for token.IsDigit(lexer.current, base) {
		lexer.consume()
	}
}

var ErrUnclosedRuneLit = fmt.Errorf("unterminated rune literal")
var ErrEmptyRuneLiteral = fmt.Errorf("empty rune literal")
var ErrTooManyRuneChars = fmt.Errorf("too many characters in rune literal")

// lexRune consumes a rune literal and emits a Rune Token. lexRune should
// only be called if the current rune is a single quote (u+0027, apostrophe).
func (lexer *Lexer) lexRune() {
	lexer.consume() // consume the starting single quote

	// Consume all the characters until the next single quote, and keep
	// track of the number of characters consumed in between.
	charsConsumed := 0
	for lexer.current != '\'' {
		// End Of File encountered before the closing quote.
		if lexer.current == eof || lexer.current == '\n' {
			lexer.raise(ErrUnclosedRuneLit)
			return
		}

		lexer.consumeRune('\'')
		charsConsumed++
	}

	// Consume the tailing single quote.
	lexer.consume()

	// A rune literal can only contain 1 character inside it
	if charsConsumed > 1 {
		lexer.raiseAtTop(ErrTooManyRuneChars)
	} else if charsConsumed < 1 {
		lexer.raiseAtTop(ErrEmptyRuneLiteral)
	}

	// emit the consumed rune literal
	lexer.emit(token.Rune)
}

var ErrUnclosedStringLit = fmt.Errorf("unterminated string literal")

// lexString consumes and emits a string token. lexString should only be
// called if the current rune is a double quote (u+0022, quotation mark).
func (lexer *Lexer) lexString() {
	// Consume the starting double quote.
	lexer.consume()

	for lexer.current != '"' {
		if lexer.current == eof || lexer.current == '\n' {
			lexer.raise(ErrUnclosedStringLit)
			return
		}

		lexer.consumeRune('"')
	}

	// Consume the tailing double quote.
	lexer.consume()

	// Emit the consumed string literal.
	lexer.emit(token.String)
}

// consumeRune consumes either a single rune or a complete escape
// sequence while inside a literal quoted with the provided rune.
func (lexer *Lexer) consumeRune(quote rune) {
	if lexer.current == '\\' {
		// \ encountered: consume an escape sequence
		lexer.consumeEscape(quote)
	} else {
		// \ not encountered: consume normal rune
		lexer.consume()
	}
}

// consumeEscape consumes an escape sequence starting from the current rune
// in the source, but does not emit anything. The rune provided to the
// function is treated as a valid escape, and used for creating and lexing
// context specific escapes like \" and \' properly and without errors.
func (lexer *Lexer) consumeEscape(quote rune) {
	// consume the starting \
	lexer.consume()

	// prefix of the hexadecimal escape and the number of hex digits
	// it requires; the values are only changed in case of hex escapes
	prefix, digits := string(lexer.current), 0

	switch lexer.current {
	case quote, '\\', 'v', 't', 'r', 'n', 'f', 'b', 'a':
		// empty case to prevent an error from being raised
		// the valid rune is consumed right after this switch

	// hex escape cases: contains a prefix followed by a fixed number
	// of hexadecimal digits representing a byte or a unicode codepoint
	case 'x':
		digits = 2 // 2 hex digits: \xFF
	case 'u':
		digits = 4 // 4 hex digits: \u00FF
	case 'U':
		digits = 8 // 8 hex digits: \U0000FFFF

	// illegal escape sequence prefix encountered
	default:
		lexer.raise(fmt.Errorf("illegal prefix %q in esacape literal", lexer.current))
	}

	// consume the starting rune of the escape literal, even if it is illegal
	lexer.consume()

	if digits > 0 {
		// consume the specified number of hex digits
		hexDigits := ""
		for i := 0; i < digits; i++ {
			// Check if next digit is valid hexadecimal.
			if !token.IsDigit(lexer.current, 16) {
				lexer.raise(fmt.Errorf("\\%v should be followed by %d hexadecimal digits", prefix, digits))
				return
			}

			hexDigits += string(lexer.current)
			lexer.consume()
		}

		// hex escape encountered: ensure escaped codepoint is valid unicode
		// error can be safely ignored since we consumed only valid hex digits
		if r, _ := strconv.ParseInt(hexDigits, 16, 32); !utf8.ValidRune(rune(r)) {
			lexer.raise(fmt.Errorf("\\%v%s represents an invalid Unicode codepoint", prefix, hexDigits))
		}
	}
}

func (lexer *Lexer) lexOperator() {
	// Consume the largest contagious subset in the source which forms a
	// valid operator, allowing multi-rune operators to be correctly lexed.
	for token.IsOperator(lexer.tokenLiteral + string(lexer.current)) {
		lexer.consume()
	}

	// Emit the consumed token and lookup the correct token type.
	lexer.emit(token.NewTokenType(lexer.tokenLiteral))
}

// lexComment consumes and emits a comment token. lexComment should only be
// called if current rune is a hash '#' (u+0023).
func (lexer *Lexer) lexComment() {
	// Comments are terminated either by a newline or by the end of the file.
	// A leading consume which consumes the '#' is unnecessary because the
	// loop will also consume any non '\n' or EOF runes, including '#'.
	for lexer.current != '\n' && lexer.current != eof {
		lexer.consume()
	}

	// Emit the consumed comment token.
	lexer.emit(token.Comment)
}
