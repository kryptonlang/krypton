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

package token

import (
	"laptudirm.com/x/krypton/pkg/krypton/file"
)

// A Token is a single lexical element of the source code. The
// structure packs a variety of information including the token
// type, its string literal representation from the source code
// and its position in the source code.
type Token struct {
	Type // type of the token

	Literal  string // literal representation in the source code
	file.Pos        // token's position in the source code
}

// Type is the enumeration representing the type of token.
type Type uint8

// Various enumerations of TokenType representing the various types of
// typeToString present in the source code.
const (
	// Special tokens

	EOF Type = iota
	Illegal
	Comment

	// Identifiers and basic type literals
	literalBeg

	Identifier // main
	Number     // 3.14
	Rune       // 'a'
	String     // "abc"

	literalEnd

	// Operators and delimiters
	operatorBeg

	Plus    // +
	Minus   // -
	Star    // *
	Slash   // /
	Percent // %

	Tilde    // ~
	Amp      // &
	Bar      // |
	Caret    // ^
	LessLess // <<
	MoreMore // >>

	PlusEqual    // +=
	MinusEqual   // -=
	StarEqual    // *=
	SlashEqual   // /=
	PercentEqual // %=

	AmpEqual      // &=
	BarEqual      // |=
	CaretEqual    // ^=
	LessLessEqual // <<=
	MoreMoreEqual // >>=

	EqualEqual // ==
	Less       // <
	More       // >
	Equal      // =
	Bang       // !

	BangEqual // !=
	LessEqual // <=
	MoreEqual // >=

	LeftParen // (
	LeftBrack // [
	LeftBrace // {
	Comma     // ,
	Period    // .

	RightParen // )
	RightBrack // ]
	RightBrace // }
	Semicolon  // ;
	Colon      // :

	operatorEnd

	// Keywords
	keywordBeg

	Underscore // _

	For  // for
	If   // if
	Else // else

	Let   // let
	Const // const

	Func // func

	Break    // break
	Continue // continue
	Return   // return
	Fall     // fallthrough

	TypeDec
	Struct
	Enum
	Interface

	Namespace

	keywordEnd
)

type tokenInfo struct {
	name, literal string
}

// typeToString maps each token type to its string representation.
// Tokens which don't have a constant string representation are instead
// represented using their token name in all caps. Tokens which have
// a constant string representation are represented using that.
//
// When adding new tokens the following things should be kept in mind:
//   - The string representation MUST follow the above-mentioned rules.
//   - Any new multi-rune operator must have the property that any
//     contagious subset of its string representation starting from the
//     first rune must also be a valid operator.
//     For example, consider the operator <<=. All of its subsets, that
//     is "<" and "<<" are also valid operators.
var typeToString = [...]tokenInfo{
	EOF:     {"EOF", ":EOF:"},
	Illegal: {"ILLEGAL", ":ILLEGAL:"},
	Comment: {"COMMENT", ":COMMENT:"},

	Identifier: {"IDENT", ":IDENT:"},
	Number:     {"NUMBER", ":NUMBER:"},
	Rune:       {"RUNE", ":RUNE:"},
	String:     {"STRING", ":STRING:"},

	Plus:    {"PLUS", "+"},
	Minus:   {"MINUS", "-"},
	Star:    {"STAR", "*"},
	Slash:   {"SLASH", "/"},
	Percent: {"PERCENT", "%"},

	Tilde:    {"TILDE", "~"},
	Amp:      {"AMPERSAND", "&"},
	Bar:      {"BAR", "|"},
	Caret:    {"CARET", "^"},
	LessLess: {"LESS_LESS", "<<"},
	MoreMore: {"MORE_MORE", ">>"},

	PlusEqual:    {"PLUS_EQUAL", "+="},
	MinusEqual:   {"MINUS_EQUAL", "-="},
	StarEqual:    {"STAR_EQUAL", "*="},
	SlashEqual:   {"SLASH_EQUAL", "/="},
	PercentEqual: {"PERCENT_EQUAL", "%="},

	AmpEqual:      {"AMP_EQUAL", "&="},
	BarEqual:      {"BAR_EQUAL", "|="},
	CaretEqual:    {"CARET_EQUAL", "^="},
	LessLessEqual: {"LESS_LESS_EQUAL", "<<="},
	MoreMoreEqual: {"MORE_MORE_EQUAL", ">>="},

	EqualEqual: {"EQUAL_EQUAL", "=="},
	Less:       {"LESS", "<"},
	More:       {"MORE", ">"},
	Equal:      {"EQUAL", "="},
	Bang:       {"BANG", "!"},

	BangEqual: {"BANG_EQUAL", "!="},
	LessEqual: {"LESS_EQUAL", "<="},
	MoreEqual: {"MORE_EQUAL", ">="},

	LeftParen: {"LEFT_PAREN", "("},
	LeftBrack: {"LEFT_BRACK", "["},
	LeftBrace: {"LEFT_BRACE", "{"},
	Comma:     {"COMMA", ","},
	Period:    {"PERIOD", "."},

	RightParen: {"RIGHT_PAREN", ")"},
	RightBrack: {"RIGHT_BRACK", "]"},
	RightBrace: {"RIGHT_BRACE", "}"},
	Semicolon:  {"SEMICOLON", ";"},
	Colon:      {"COLON", ":"},

	Underscore: {"UNDERSCORE", "_"},

	For:  {"FOR", "for"},
	If:   {"IF", "if"},
	Else: {"ELSE", "else"},

	Let:   {"LET", "let"},
	Const: {"CONST", "const"},

	Func: {"FUNC", "func"},

	Break:    {"BREAK", "break"},
	Continue: {"CONTINUE", "continue"},
	Return:   {"RETURN", "return"},
	Fall:     {"FALLTHROUGH", "fallthrough"},

	TypeDec:   {"TYPE", "type"},
	Struct:    {"STRUCT", "struct"},
	Enum:      {"ENUM", "enum"},
	Interface: {"INTERFACE", "interface"},

	Namespace: {"NAMESPACE", "namespace"},
}

// stringToType maps each TokenType's string representation to its TokenType.
var stringToType map[string]Type

func init() {
	// populate the stringToType map
	stringToType = make(map[string]Type, len(typeToString))

	for tokenType, tokenInfo := range typeToString {
		if tokenInfo.literal != "" {
			stringToType[tokenInfo.literal] = Type(tokenType)
		}
	}
}

// NewTokenType creates a new TokenType from the given string literal.
func NewTokenType(str string) Type {
	tokenType, _ := stringToType[str]
	return tokenType
}

// String returns the string representation of the given TokenType.
func (tok Type) String() string {
	return typeToString[tok].name
}

// InsertSemiAfter returns a boolean explaining whether automatic
// semicolon insertion should occur after a token of the given type.
func (tok Type) InsertSemiAfter() bool {
	// semicolon insertion occurs after all literals
	if tok.IsLiteral() {
		return true
	}

	switch tok {
	// semicolon insertion also occurs after all keywords and operators
	// which can possibly be present as the last token in a statement
	case RightParen, RightBrack, RightBrace, Break, Continue, Return:
		return true
	default:
		return false
	}
}

// IsLiteral checks if the given TokenType is a literal type.
func (tok Type) IsLiteral() bool {
	return literalBeg < tok && tok < literalEnd
}

// IsOperator checks if the given TokenType is an operator type.
func (tok Type) IsOperator() bool {
	return operatorBeg < tok && tok < operatorEnd
}

// IsKeyword checks if the given TokenType is a keyword type.
func (tok Type) IsKeyword() bool {
	return keywordBeg < tok && tok < keywordEnd
}

// IsOperator returns a boolean depending on whether name is a valid
// operator or not. If the string belongs in the list of mash operators,
// it is a valid operator.
func IsOperator(s string) bool {
	return NewTokenType(s).IsOperator()
}

// Lookup checks if name is a keyword, and returns the token type of the
// keyword if it is. Otherwise, it returns IDENT.
func Lookup(name string) Type {
	if tok, ok := stringToType[name]; ok && tok.IsKeyword() {
		return tok
	}

	return Identifier
}

// IsDigit checks if the given rune is a digit of the given base.
func IsDigit(r rune, base int) bool {
	switch r {
	case 'A', 'B', 'C', 'D', 'E', 'F',
		'a', 'b', 'c', 'd', 'e', 'f':
		return base == 16
	case '8', '9':
		return base >= 10
	case '2', '3', '4', '5', '6', '7':
		return base >= 8
	case '0', '1':
		return true
	default:
		return false
	}
}
