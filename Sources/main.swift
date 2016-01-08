import Darwin.C;

enum Value {
    case Fixnum(n: Int)
    case True
    case False
    case ChrLit(c: CInt)
    case StrLit(s: String)
    case Nil
    indirect case Pair(first: Value, second: Value)
    case Symbol(s: String)
    case PrimitiveProc(p: Value -> Value)
}

func == (a: Value, b: Value) -> Bool {
    switch (a, b) {
        case (.Fixnum(let n1), .Fixnum(let n2)) where n1 == n2: return true
        case (.Symbol(let s1), .Symbol(let s2)) where s1 == s2: return true
        case (.ChrLit(let c1), .ChrLit(let c2)) where c1 == c2: return true
        case (.StrLit(let s1), .StrLit(let s2)) where s1 == s2: return true
        case (.True, .True): return true
        case (.Nil, .Nil): return true
        // very slow
        case (.Pair(first: let f1, second: let s1), .Pair(first: let f2, second: let s2)) where f1 == f2 && s1 == s2: return true
        // equality for functions is not supported in swift
        case (.PrimitiveProc(_), .PrimitiveProc(_)): fallthrough
        default: return false
    }
}

//

func car(v: Value) -> Value {
    switch (v) {
        case .Pair(let f, _): return f
        default: 
            print("car: fatal error")
            exit(-1)
    }
}

func cdr(v: Value) -> Value {
    switch (v) {
        case .Pair(_, let s): return s
        default: 
            print("cdr: fatal error")
            exit(-1)
    }
}

func cadr(v: Value) -> Value {
    return car(cdr(v))
}

func cddr(v: Value) -> Value {
    return cdr(cdr(v))
}

func caddr(v: Value) -> Value {
    return cadr(cdr(v))
}

func cdddr(v: Value) -> Value {
    return cdr(cddr(v))
}

func cadddr(v: Value) -> Value {
    return car(cdddr(v))
}

//
func IsFixnum(v: Value) -> Bool {
    switch (v) {
        case .Fixnum(_): return true
        default: return false
    }
}

func IsSymbol(v: Value) -> Bool {
    switch (v) {
        case .Symbol(_): return true
        default: return false
    }
}

func IsStrLit(v: Value) -> Bool {
    switch (v) {
        case .StrLit(_): return true
        default: return false
    }
}

func IsChrLit(v: Value) -> Bool {
    switch (v) {
        case .ChrLit(_): return true
        default: return false
    }
}

func IsPair(v: Value) -> Bool {
    switch (v) {
        case .Pair(_, _): return true
        default: return false
    }
}

func IsProcedure(v: Value) -> Bool {
    switch (v) {
        case .PrimitiveProc(_): return true
        default: return false
    }
}

func IsBoolean(v: Value) -> Bool {
    switch (v) {
        case .True: return true
        case .False: return true
        default: return false
    }
}

//
let END_OF_LINE: CInt = 10
let SEMICOLON: CInt = 59
let MINUS = CInt(UInt8(ascii: "-"))
let PLUS = CInt(UInt8(ascii: "+"))
let ZERO: CInt = 48
let SHARP: CInt = 35 // '#'
let NEWLINE: CInt = 10 // '\n'
let SPACE: CInt = 32 // ' '
let BSLASH: CInt = 92 // '\\'
let T: CInt = 116 // 't'
let F: CInt = 102 // 'f'

let STAR  = CInt(UInt8(ascii: "*"))
let SLASH = CInt(UInt8(ascii: "/"))
let GT    = CInt(UInt8(ascii: ">"))
let LT    = CInt(UInt8(ascii: "<"))
let EQUALS = CInt(UInt8(ascii: "="))
let QMARK = CInt(UInt8(ascii: "?"))
let MARK  = CInt(UInt8(ascii: "!"))

func _IsDelimiter(c: CInt) -> Bool {
    return isspace(c) != 0    || c == EOF /* -1  */ || 
           c == 40 /* '(' */  || c == 41  /* ')' */ ||
           c == 34 /* '"' */  || c == SEMICOLON  /* ';' */
}

func _IsInitial(c: CInt) -> Bool {
    return isalpha(c) != 0    || c == STAR || c == SLASH  ||
           c == LT            || c == GT   || c == EQUALS ||
           c == QMARK         || c == MARK
}

func _EatWhitespace(stream: UnsafeMutablePointer<FILE>) {
    var c = getc(stream)
    while c != EOF {
        if isspace(c) != 0 {
            c = getc(stream)
            continue
        } else if c == SEMICOLON { /* comments are whitespace also */
            repeat {
                c = getc(stream)
            } while c != EOF && c != END_OF_LINE
            c = getc(stream)
            continue
        }
        ungetc(c, stream)
        break
    } 
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

func _ReadPair(stream: UnsafeMutablePointer<FILE>) -> Value? {
    _EatWhitespace(stream)
    var c = getc(stream)
    if c == CInt(UInt8(ascii: ")")) {
        return .Nil /* the empty list */
    }
    ungetc(c, stream)

    let car = Read(stream)
    _EatWhitespace(stream)

    c = getc(stream)
    if c == CInt(UInt8(ascii: ".")) { /* read improper list */
        c = _Peek(stream)
        if !_IsDelimiter(c) {
            print("dot not followed by delimiter")
            exit(-1)
        }
        let cdr = Read(stream)
        _EatWhitespace(stream)
        c = getc(stream)
        if c != CInt(UInt8(ascii: ")")) {
            print("where was the trailing right paren?")
            exit(-1)
        }
        return .Pair(first: car as Value!, second: cdr as Value!)
    } else { /* read list */
        ungetc(c, stream)
        let cdr = _ReadPair(stream)
        return .Pair(first: car as Value!, second: cdr as Value!)
    }
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
    } else if _IsInitial(c) || ((c == PLUS || c == MINUS) && _IsDelimiter(_Peek(stream))) { /* read a symbol */
        var buffer = String()
        
        while _IsInitial(c) || isdigit(c) != 0 || c == PLUS || c == MINUS {
            buffer.append(UnicodeScalar(UInt32(c)))
            c = getc(stream)
        }
        ungetc(c, stream)
        return .Symbol(s: buffer)
    } else if c == CInt(UInt8(ascii: "(")) { /* read the empty list or pair */
        return _ReadPair(stream)
    } else if c == CInt(UInt8(ascii: "'")) {
        let v = Read(stream)
        return .Pair(first: Quote, second: .Pair(first: v as Value!, second: .Nil))
    } else {
        var s = String()
        s.append(UnicodeScalar(UInt32(c)))
        print("bad input. unexpected '\(s)'")
        exit(-1)
    }
    print("illegal read state")
    exit(-1)
}

//
class Environment {
    let base: Environment?
    var frame: [String : Value] = [:]

    init(base: Environment?) {
        self.base = base
    }
    
    func EnclosingEnvironment() -> Environment? {
        return base
    }
    
    func LookupValue(name: String) -> Value? {
        return frame[name]
    }
    
    func SetVariableValue(name: String, value: Value) {
        if self === Environment.Empty {
            print("unbound varible '\(name)'")
            exit(-1)
        } else if frame[name] != nil {
            frame[name] = value
        } else if base != nil {
            base!.SetVariableValue(name, value: value)
        }
    }
    
    func DefineVariable(name: String, value: Value) {
        frame[name] = value
    }

    static func Extend(env: Environment) -> Environment {
        return Environment(base: env)
    }

    static func Setup() -> Environment {
        return Extend(Empty) 
    }

    static let Empty  = Environment(base: nil)
    static let Global = Environment.Setup()
}


let Quote  = Value.Symbol(s: "quote" )
let Define = Value.Symbol(s: "define")
let OK     = Value.Symbol(s: "ok"    )
let SetV   = Value.Symbol(s: "set!"  )
let IF     = Value.Symbol(s: "if"    )


func _IsSelfEvaluating(v: Value) -> Bool {
    return IsBoolean(v) || IsFixnum(v) || IsChrLit(v) || IsStrLit(v)
}

func _IsTagged(expression: Value, tag: Value) -> Bool {
   if IsPair(expression) {
        let first = car(expression)
        return IsSymbol(first) && (first == tag)
   }
   return false
}

func _IsQuoted(expression: Value) -> Bool {
    return _IsTagged(expression, tag: Quote)
}

func _QuotationText(quoted: Value) -> Value {
    return cadr(quoted)
}

//
func _IsVariable(expression: Value) -> String? {
    if case .Symbol(let s) = expression {
        return s
    }
    return nil
}

func _IsAssignment(form: Value) -> Bool {
    return _IsTagged(form, tag: SetV)
}

func _AssignmentVarName(assignment: Value) -> String {
    switch cadr(assignment) {
    case .Symbol(let s): return s
    default:
        print("invalid variable name")
        exit(-1)
    }
}

func _AssignmentValue(assignment: Value) -> Value {
    return cadr(cdr(assignment))
}

func _EvalAssignment(assignment: Value, env: Environment) -> Value {
    env.SetVariableValue(_AssignmentVarName(assignment), value: Eval(_AssignmentValue(assignment), env:  env))
    return OK
}

func _IsDefinition(form: Value) -> Bool {
    return _IsTagged(form, tag: Define)
}

func _DefinitionVariableName(definition: Value) -> String {
    switch cadr(definition) {
    case .Symbol(let s): return s
    default:
        print("invalid variable name")
        exit(-1)
    }
}

func _DefinitionValue(definition: Value) -> Value {
    return cadr(cdr(definition))
}

func _EvalDefinition(form: Value, env: Environment) -> Value {
    env.DefineVariable(_DefinitionVariableName(form), value: Eval(_DefinitionValue(form), env:  env))
    return OK
}
//
func _IsIf(form: Value) -> Bool {
    return _IsTagged(form, tag: IF)
}

func _IfPredicate(form: Value) -> Value {
    return cadr(form)
}

func _IfConsequent(form: Value) -> Value {
    return caddr(form)
}

func _IfAlternative(form: Value) -> Value {
    if cdddr(form) == .Nil {
        return .False
    } else {
        return cadddr(form)
    }
}

//

//

func Eval(v: Value, env: Environment) -> Value {
    var exp = v
    while true {
        if _IsSelfEvaluating(exp) {
            return exp
        } else if let name = _IsVariable(exp) {
            switch (env.LookupValue(name)) {
            case .Some(let value): return value
            case .None:
                print("unbound variable '\(name)'")
                exit(-1)
            }
        } else if (_IsQuoted(exp)) {
            return _QuotationText(exp)
        } else if _IsAssignment(exp) {
            return _EvalAssignment(exp, env: env)
        } else if _IsDefinition(exp) {
            return _EvalDefinition(exp, env: env)
        } else if _IsIf(exp) {
            exp = Eval(_IfPredicate(exp), env: env) == .True ? _IfConsequent(exp) : _IfAlternative(exp)
            continue // tailcall
        } else if _IsApplication(exp) {
            let procedure = Eval(_ApplicationOperator(exp), env: env)
            let arguments = _EvalOperands(_ApplicationOperands(exp), env: env)
            if case .PrimitiveProc(let proc) = procedure {
                return proc(arguments)
            } else 
            {
                print("invalid form")
                exit(-1)
            }
        } else {
            print("cannot eval unknown expression type")
            exit(-1)
        }
    }
}

//
func _WriteChrLit(c: CInt) {
    _Print("#\\")
    switch (c) {
        case NEWLINE: print("newline")
        case SPACE: print("space")
        default:
            var s = String()
            s.append(UnicodeScalar(UInt32(c)))
            _Print(s)
    }
}

func _WriteStrLit(s: String) {
    _Print("\"")
    for c in s.characters {
        if c == "\n" {
            _Print("\\n")
        } else if c == "\\" {
            _Print("\\\\")
        } else if c == "\"" {
            _Print("\\\"")
        } else {
            _Print(c)
        }
    }
    _Print("\"")
}

func _WritePair(first: Value, _ second: Value) {
    Write(first)
    switch (second) {
        case .Pair(let f, let s): 
            _Print(" ")
            _WritePair(f, s)
        case .Nil: () /* do nothing */
        default: 
            _Print(" . ")
            Write(second)
    }
}

func _Print<T>(v: T) {
    print(v, terminator:"")
}

func Write(v: Value) {
    switch (v) {
        case .Fixnum(let n): _Print(n)
        case .True: _Print("#t")
        case .False: _Print("#f")
        case .ChrLit(let c): _WriteChrLit(c)
        case .StrLit(let s): _WriteStrLit(s)
        case .Nil: _Print("()")
        case .Pair(let f, let s): 
            _Print("(")
            _WritePair(f, s)
            _Print(")")
        case .Symbol(let s): _Print(s)
        case .PrimitiveProc(_): _Print("#<procedure>")
    }
}

// 
func _IsApplication(form: Value) -> Bool {
    return IsPair(form)
}

func _ApplicationOperator(form: Value) -> Value {
    return car(form)
}

func _ApplicationOperands(form: Value) -> Value {
    return cdr(form)
}

func _ApplicationOperandsEmpty(operands: Value) -> Bool {
    return operands == .Nil
}

func _FirstOperand(operands: Value) -> Value {
    return car(operands)
}

func _RestOperands(operands: Value) -> Value {
    return cdr(operands)
}

func _EvalOperands(operands: Value, env: Environment) -> Value {
    if operands == .Nil {
        return .Nil
    }
    return .Pair(first:   Eval(_FirstOperand(operands), env: env), 
                 second: _EvalOperands(_RestOperands(operands), env: env))
}

//
func _ProcAdd(arguments: Value) -> Value {
    var result = 0
    var cur_args = arguments
    while !(cur_args == Value.Nil) {
        let first = car(cur_args)
        if case .Fixnum(let n) = first {
            result += n
        } else {
            print("invalid operand (+)")
            exit(-1)
        }
        cur_args = cdr(cur_args)
    }
    return .Fixnum(n: result)
}

func _ProcNumEq(arguments: Value) -> Value {
    var v = 0
    var cur_args = arguments
    switch car(cur_args) {
        case .Fixnum(let n): v = n
        default:
            print("invalid arguments")
            exit(-1)
    }

    cur_args = cdr(cur_args)
    while !(cur_args == .Nil) {
        switch car(cur_args) {
            case .Fixnum(let n): if v != n { return .False }
            default:
                print("invalid arguments")
                exit(-1)
        }
        cur_args = cdr(cur_args)
    }
    
    return .True
}

func _ProcIsBoolean(arguments: Value) -> Value {
    let first = car(arguments)
    return (first == .True || first == .False) ? .True : .False
}

func _ProcCharToInteger(arguments: Value) -> Value {
    if case .ChrLit(let c) = car(arguments) {
        return .Fixnum(n: Int(c)) 
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcIntegerToChar(arguments: Value) -> Value {
    if case .Fixnum(let n) = car(arguments) {
        return .ChrLit(c: CInt(UInt8(ascii: UnicodeScalar(n))))
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcNumberToString(arguments: Value) -> Value {
    if case .Fixnum(let n) = car(arguments) {
        return .StrLit(s: String(n))
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcStringToNumber(arguments: Value) -> Value {
    if case .StrLit(let s) = car(arguments) {
        if let n = Int(s) {
            return .Fixnum(n: n)
        }
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcSymbolToString(arguments: Value) -> Value {
    if case .Symbol(let s) = car(arguments) {
        return .StrLit(s: s)
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcStringToSymbol(arguments: Value) -> Value {
    if case .StrLit(let s) = car(arguments) {
        return .Symbol(s: s)
    }
    print("invalid arguments")
    exit(-1)
}

Environment.Global.DefineVariable("null?"     , value: .PrimitiveProc(p: {car($0) == .Nil ? .True : .False}))
Environment.Global.DefineVariable("boolean?"  , value: .PrimitiveProc(p: _ProcIsBoolean))
Environment.Global.DefineVariable("symbol?"   , value: .PrimitiveProc(p: {IsSymbol(car($0)) ? .True : .False }))
Environment.Global.DefineVariable("integer?"  , value: .PrimitiveProc(p: {IsFixnum(car($0)) ? .True : .False}))
Environment.Global.DefineVariable("character?", value: .PrimitiveProc(p: {IsChrLit(car($0)) ? .True : .False}))
Environment.Global.DefineVariable("string?"   , value: .PrimitiveProc(p: {IsStrLit(car($0)) ? .True : .False}))
Environment.Global.DefineVariable("pair?"     , value: .PrimitiveProc(p: {IsPair(car($0)) ? .True : .False}))
Environment.Global.DefineVariable("procedure?", value: .PrimitiveProc(p: {IsProcedure(car($0)) ? .True : .False}))

Environment.Global.DefineVariable("char->integer" , value: .PrimitiveProc(p: _ProcCharToInteger))
Environment.Global.DefineVariable("integer->char" , value: .PrimitiveProc(p: _ProcIntegerToChar))
Environment.Global.DefineVariable("number->string", value: .PrimitiveProc(p: _ProcNumberToString))
Environment.Global.DefineVariable("string->number", value: .PrimitiveProc(p: _ProcStringToNumber))
Environment.Global.DefineVariable("symbol->string", value: .PrimitiveProc(p: _ProcSymbolToString))
Environment.Global.DefineVariable("string->symbol", value: .PrimitiveProc(p: _ProcStringToSymbol))

Environment.Global.DefineVariable("+", value: .PrimitiveProc(p: _ProcAdd))
Environment.Global.DefineVariable("=", value: .PrimitiveProc(p: _ProcNumEq))


Environment.Global.DefineVariable("cons", value: .PrimitiveProc(p: { .Pair(first: car($0), second: cadr($0)) }))
Environment.Global.DefineVariable("car" , value: .PrimitiveProc(p: { car($0) }))
Environment.Global.DefineVariable("cdr" , value: .PrimitiveProc(p: { cdr($0) }))
Environment.Global.DefineVariable("list", value: .PrimitiveProc(p: { $0 }))
Environment.Global.DefineVariable("eq?" , value: .PrimitiveProc(p: { car($0) == cadr($0) ? .True : .False }))


//
print("Welcome to Sanguinius v0.12. Use ctrl-c to exit")

repeat {
    print("> ", terminator:"")
    if let v = Read(stdin) {
        Write(Eval(v, env: Environment.Global))
    }
    print("")

} while true
