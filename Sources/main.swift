import Darwin.C;

enum Value {
    case Fixnum(n: Int)
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

func _Peek(stream: UnsafeMutablePointer<FILE>) -> CInt {
    let c = getc(stream)
    ungetc(c, stream)
    return c
}

func Read(stream: UnsafeMutablePointer<FILE>) -> Value? {
    _EatWhitespace(stream)
    var c = getc(stream)
    var sign = 1
    var num = 0
    if isdigit(c) != 0 || (c == MINUS && (isdigit(_Peek(stream)) != 0)) {
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

func Write(v: Value) {
    switch (v) {
        case .Fixnum(let n): print(n)
        default: print("#error")
    }
}

//
print("Welcome to Sanguinius v0.1. Use ctrl-c to exit")

repeat {
    print("> ", terminator:"")
    if let v = Eval(Read(stdin)) {
        Write(v)
    }
    print("")

} while true
