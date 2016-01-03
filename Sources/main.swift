import Darwin.C;

enum Value {
    case Fixnum(n: Int)
    case True
    case False
    case ChrLit(c: CInt)
    case StrLit(s: String)
    case Nil
}

func IsFixnum(v: Value) -> Bool {
    switch (v) {
        case .Fixnum(_): return true
        default: return false
    }
}
//
let END_OF_LINE: CInt = 10
let SEMICOLON: CInt = 59
let MINUS: CInt = 40
let ZERO: CInt = 48
let SHARP: CInt = 35 // '#'
let NEWLINE: CInt = 10 // '\n'
let SPACE: CInt = 32 // ' '
let BSLASH: CInt = 92 // '\\'
let T: CInt = 116 // 't'
let F: CInt = 102 // 'f'

func _IsDelimiter(c: CInt) -> Bool {
    return isspace(c) != 0    || c == EOF /* -1  */ || 
           c == 40 /* '(' */  || c == 41  /* ')' */ ||
           c == 34 /* '"' */  || c == SEMICOLON  /* ';' */
}

func _EatWhitespace(stream: UnsafeMutablePointer<FILE>) {
    var c: CInt = EOF
    repeat {    
        c = getc(stream)
        if isspace(c) != 0 {
            continue
        } else if (c == SEMICOLON) { /* comments are whitespace also */
            repeat {
                c = getc(stream)
            } while c != EOF && c != END_OF_LINE
            continue
        }
        ungetc(c, stream)
        break
    } while c != EOF
}

func _EatExpectedStrLit(stream: UnsafeMutablePointer<FILE>, _ lit: String) {
    for ch in lit.utf8 {
        let c = getc(stream)
        if c != CInt(ch) {
            print("unexpected character \(c)")
            exit(-1)
        }
    }
}

func _PeekExpectedDelimiter(stream: UnsafeMutablePointer<FILE>) {
    if !_IsDelimiter(_Peek(stream)) {
        print("character not followed by delimiter")
        exit(-1)
    }
}

func _Peek(stream: UnsafeMutablePointer<FILE>) -> CInt {
    let c = getc(stream)
    ungetc(c, stream)
    return c
}

func _ReadChr(stream: UnsafeMutablePointer<FILE>) -> Value {
    let c = getc(stream)
    if c == EOF {
        print("incomplete character literal")
        exit(-1)
    } else if c == CInt(UInt8(ascii: "s")) {
        if _Peek(stream) == CInt(UInt8(ascii: "p")) {
            _EatExpectedStrLit(stream, "pace")
            _PeekExpectedDelimiter(stream)
            return .ChrLit(c: SPACE)
        }
        
    } else if c == CInt(UInt8(ascii: "e")) {
        if _Peek(stream) == CInt(UInt8(ascii: "e")) {
            _EatExpectedStrLit(stream, "ewline")
            _PeekExpectedDelimiter(stream)
            return .ChrLit(c: NEWLINE)
        }
    }
    _PeekExpectedDelimiter(stream)
    return .ChrLit(c: c)
}

func Read(stream: UnsafeMutablePointer<FILE>) -> Value? {
    _EatWhitespace(stream)
    var c = getc(stream)
    var sign = 1
    var num = 0

    if c == SHARP { /* read a boolean or character */
        c = getc(stream)
        switch (c) {
            case T: return .True
            case F: return .False
            case BSLASH: return _ReadChr(stream)
            default: 
                print("unknown boolean or character literal")
                exit(-1)
            
        }
    } else if isdigit(c) != 0 || (c == MINUS && (isdigit(_Peek(stream)) != 0)) {
        if c == MINUS {
            sign = -1
        } else {
            ungetc(c, stream)
        }
        c = getc(stream)
        while (isdigit(c) != 0) {
            num = num * 10 + c - ZERO
            c = getc(stream)
        }
        num = num * sign
        if _IsDelimiter(c) {
            ungetc(c, stream)
            return .Fixnum(n: num)
        } else {
            print("number not followed by delimiter")
            exit(-1)
        }
    } else if c == CInt(UInt8(ascii: "\"")) { /* read a string */
        var buffer = String()
        c = getc(stream)
        while c != CInt(UInt8(ascii: "\"")) {
            if c == CInt(UInt8(ascii: "\\")) {
                c = getc(stream)
                if c == CInt(UInt8(ascii: "n")) {
                    c = CInt(UInt8(ascii: "\n"))
                }
            }

            if c == EOF {
                print("non-terminated string literal")
                exit(-1)
            }
            buffer.append(UnicodeScalar(UInt32(c)))
            c = getc(stream)
        }
        return .StrLit(s: buffer)
    } else if c == CInt(UInt8(ascii: "(")) {
        _EatWhitespace(stream)
        c = getc(stream)
        if c == CInt(UInt8(ascii: ")")) {
            return .Nil
        } else {
            print("unexpected character \(c). expected ')'")
            exit(-1)
        }
    } else {
        print("bad input. unexpected \(c)")
        exit(-1)
    }
    print("illegal read state")
    exit(-1)
}

func Eval(v: Value?) -> Value? {
    return v 
}

func _WriteChrLit(c: CInt) {
    print("#\\", terminator:"")
    switch (c) {
        case NEWLINE: print("newline")
        case SPACE: print("space")
        default:
            var s = String()
            s.append(UnicodeScalar(UInt32(c)))
            print(s)
    }
}

func _WriteStrLit(s: String) {
    print("\"", terminator:"")
    for c in s.characters {
        if c == "\n" {
            print("\\n", terminator:"")
        } else if c == "\\" {
            print("\\\\", terminator:"")
        } else if c == "\"" {
            print("\\\"", terminator:"")
        } else {
            print(c, terminator:"")
        }
    }
    print("\"")
}

func Write(v: Value) {
    switch (v) {
        case .Fixnum(let n): print(n)
        case .True: print("#t")
        case .False: print("#f")
        case .ChrLit(let c): _WriteChrLit(c)
        case .StrLit(let s): _WriteStrLit(s)
        case .Nil: print("()")
    }
}

//
print("Welcome to Sanguinius v0.5. Use ctrl-c to exit")

repeat {
    print("> ", terminator:"")
    if let v = Eval(Read(stdin)) {
        Write(v)
    }
    print("")

} while true
