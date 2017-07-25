
# The (Incomplete) Kai Programming Language Specification

# Notation
Same as the [Go Specifications](https://golang.org/ref/spec#Notation) (EBNF)

    letter       = UnicodeLetter | "_" .
    decimalDigit = "0" … "9" .
    octalDigit   = "0" … "7" .
    hexDigit     = "0" … "9" | "A" … "F" | "a" … "f" .

# Identifiers

    identifier = letter { letter | unicode_digit } .

# Terminator

In Kai a terminator may be either a newline or a `;`

    Term = ";" | "\n" .

# Blocks
A _block_ is a sequence of statements (possibly zero) within matching braces.

    Block = "{" { Statement Term } "}"

In addition to explicit blocks in source code there exist a number of implicit blocks:

- Files have their own blocks, containing the source of the file and exporting all toplevel declarations.
- `if`, `for`, and `switch` statements have their own implicit blocks.
- Each `case` in a switch statement has it's own implicit block.

Blocks nest and influence scoping.

Blocks may appear arbitrarily to group code and ensure variables remain local:

    draw :: fn (width, height: f32) -> void {

        gl.begin(gl.TRIANGLES);
        defer gl.end();

        { // Fill background
            tl := V2 { 0, 0 }
            tr := V2 { width, 0 }
            bl := V2 { 0, height }
            br := V2 { width, height }

            gl.color3f(0, 0, 1)
            gl.vertex3f(tl.x, tl.y, 0)
            gl.vertex3f(tr.x, tr.y, 0)
            gl.vertex3f(br.x, br.y, 0)

            gl.vertex3f(tl.x, tl.y, 0)
            gl.vertex3f(br.x, br.y, 0)
            gl.vertex3f(bl.x, bl.y, 0)
        }

        { // Fill foreground
            inset := V2 { 10, 10 }
            tl := V2 { 0 + inset.x,     0 + inset.y }
            tr := V2 { width - inset.x, 0 - inset.y }
            bl := V2 { 0 + inset.x,     height - inset.y }
            br := V2 { width - inset.x, height - inset.y }

            gl.color3f(0, 1, 0)
            gl.vertex3f(tl.x, tl.y, 0)
            gl.vertex3f(tr.x, tr.y, 0)
            gl.vertex3f(br.x, br.y, 0)

            gl.vertex3f(tl.x, tl.y, 0)
            gl.vertex3f(br.x, br.y, 0)
            gl.vertex3f(bl.x, bl.y, 0)
        }
    }

# Scoping

Kai is lexically scoped using blocks:

> Compiler builtins are declared in the _global scope_

# Literals

## Integer Literals

    integerLit = decimalLit | binaryLit | octalLit | hexLit .
    decimalLit = ( "1" … "9" ) { decimalDigit } .
    binaryLit  = "0b" { BinaryDigit } .
    octalLit   = "0o" { octalDigit } .
    hexLit     = "0x" hexDigit { hexDigit } .

## Floating-Point Literals

    floatLit = decimals "." [ decimals ] [ exponent ] |
               decimals exponent .
    decimals = decimalDigit { decimalDigit } .
    exponent = ( "e" | "E" ) [ "+" | "-" ] decimals .

## String Literals

    stringLit = '"' { unicodeValue } '"'

## Function Literals

    FunctionLit    = "fn" Signature Block .
    Signature      = "(" [ NamedParameter { "," NamedParameter } ] ")" "->" ExprList .
    NamedParameter = Identifier { "," Identifier } ":" Expr .

## Composite Literals

    CompositeLit = LiteralType LiteralValue .
    LiteralType  = (Type | "[" ".." "]" Type) .
    LiteralValue = "{" [ ElementList [","] ] "}" .
    ElementList  = Element { "," Element } .
    Element      = NamedField | Expr .
    NamedField   = identifier ":" Expr .

# Directives

Directives are special in that some may not modify the node on which they operate other than setting flags.
For example:

```go
#foreign libc #callingConvention "c" {
    #discardable
    printf :: fn (fmt: string, args: #cvargs ..any) -> i32
}
```

Here the `foreign` and `callingConvention` directives will expect a block or a declaration to follow it.
 Both directives will return the value they expect with appropriate flags set. In this case the block will
 set the calling convention of it's member declarations to be `"c"` and will mark all of it's declarations
 as foreign.
Likewise the `discardable` and `cvargs` directives will expect a function declaration and variadic statement 
  to follow them. Both will simply set flags and return the value they expect.

In terms of grammer, the following directives are not values themselves and *may not* be referred to elsewhere.

    Foreign      = "#foreign" ( LibName ForeignBlock | LibName ForeignDecl ) .
    Discardable  = "#discardable" ( FunctionDecl | ForeignFunctionDecl ) .
    LinkName     = "#linkName" ( SingularDecl | UninitializedDecl ) .
    Cvargs       = "#cvargs" Variadic .
    ForeignBlock = "{" { ForeignDecl Term } "}"

The following Directives are distinct values and *may* be referred to else elsewhere.

    Library = "#library" stringLit [ SymbolAlias ] .
    Import  = "#import" stringLit [ SymbolAlias ] .

    LibName     = identifier .
    SymbolAlias = identifier .

# Special Values

Because the languages grammer is not context free the following declarations exist to indicate that the 
  parser had a certain state when parsing otherwise regular statements.

## Foreign State

    ForeignDecl = ( ForeignFunctionDecl | UninitializedDecl ) .
    ForeignFunctionDecl = identifier "::" FunctionType .

# Declarations

TODO: The value ExprList *must* be singular for all Literals that are not Basic.

    Decl              = IdentifierList ":" [ Type ] ( ( ":" | "=" ) ExprList ) .
    FunctionDecl      = identifier "::" FunctionLit .
    StructDecl        = identifier "::" StructType .
    UnionDecl         = identifier "::" UnionType .
    UninitializedDecl = IdentifierList ":" Type .
    IdentifierList    = identifier { "," identifier } .

    SingularDecl              = SingularInitializedDecl | SingularUninitializedDecl .
    SingularInitializedDecl   = identifier ":" [ Type ] ( ":" | "=" ) Expr .
    SingularUninitializedDecl = identifier ":" Type .

# Expressions

    Expr         = "(" Expr ")" | Literal |
                    Deref | Expr Call |
                    ArrayType | SliceType | PointerType | FunctionType |
                    StructType | UnionType .
    Literal      = integerLit | floatLit | FunctionLit |  . (* TODO *)
    Deref        = "<" Expr .
    Call         = "(" [ ArgumentList ] ")" .
    ArgumentList = Argument { "," Argument } .
    Argument     = ( Expr | Identifier ":" Expr ) .
    ExprList     = Expr { "," Expr } .

# Types

Types are just Expressions.

    Type        = Expr .
    SliceType   = "[]" Type .
    ArrayType   = "[" integerLit "]" Type .
    PointerType = "*" Type .

## FunctionType

    FunctionType  = "fn" Parameters "->" ExprList .
    Parameters    = "(" [ ParameterList ] ")" .
    ParameterList = Parameter { "," Parameter } .
    Parameter     = ( Type | Variadic ) .
    Variadic      = ".." Type .

## StructType

    StructType      = "struct" "{" { StructFieldList } "}" .
    StructFieldList = StructFieldDecl { Term StructFieldDecl Term } .
    StructFieldDecl = [ using ] (ExprList ":" Expr | Expr) [ Tag ] .
    Tag             = "@" Identifier [ "(" ArgumentList ")" ] .

## UnionType

    UnionType      = "union" "{" UnionFieldList "}" .
    UnionFieldList = UnionFieldDecl { Term UnionFieldDecl } .
    UnionFieldDecl = ExprList ":" Expr .

## EnumType

Enumeration types are a way to represent a finite state.
They allow an _associated value_ of any type. The associated value *must* be known at compile time.

For enumerations where the associated type is *not* an integer type the actual size of an enum has
  no association with it's associated type. Instead the size of an enum is always the minimum number
  of bits required to assign a unique value for each case.

This size can be determined by:

    floor(log2(n - 1) + 1)

Where `n` is the number of cases for enums where the associated value is not provided or is a non integer type
Otherwise `n` is the maximum value of the enumeration.

When an enum's associated type is an Integer the value may be omitted and the case value will be the value of
  the previous case's value incremented.
When an enum's associated type is `string` the value may be omitted and the case name will be used as the value.

    EnumType = "enum" [ Type ] "{" EnumFieldList "}" .
    EnumFieldList = EnumFieldDecl { Term EnumFieldDecl } .
    EnumFieldDecl = identifier [ "=" Expr ] [ Tag ] .

