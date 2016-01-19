#if os(Linux)
import Glibc;
#else
import Darwin.C
#endif

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

//
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
            return CharacterLit(c: SPACE)
        }
        
    } else if c == CInt(UInt8(ascii: "e")) {
        if _Peek(stream) == CInt(UInt8(ascii: "e")) {
            _EatExpectedStrLit(stream, "ewline")
            _PeekExpectedDelimiter(stream)
            return CharacterLit(c: NEWLINE)
        }
    }
    _PeekExpectedDelimiter(stream)
    return CharacterLit(c: c)
}

func _ReadPair(stream: UnsafeMutablePointer<FILE>) -> Value? {
    _EatWhitespace(stream)
    var c = getc(stream)
    if c == CInt(UInt8(ascii: ")")) {
        return Nil /* the empty list */
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
        return Pair(fst: car as Value!, snd: cdr as Value!)
    } else { /* read list */
        ungetc(c, stream)
        let cdr = _ReadPair(stream)
        return Pair(fst: car as Value!, snd: cdr as Value!)
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
            case T: return True
            case F: return False
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
            return Fixnum(n: num)
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
        return StringLit(s: buffer)
    } else if _IsInitial(c) || ((c == PLUS || c == MINUS) && _IsDelimiter(_Peek(stream))) { /* read a symbol */
        var buffer = String()
        
        while _IsInitial(c) || isdigit(c) != 0 || c == PLUS || c == MINUS {
            buffer.append(UnicodeScalar(UInt32(c)))
            c = getc(stream)
        }
        ungetc(c, stream)
        return Symbol.CreateSymbol(buffer)
    } else if c == CInt(UInt8(ascii: "(")) { /* read the empty list or pair */
        return _ReadPair(stream)
    } else if c == CInt(UInt8(ascii: "'")) {
        let v = Read(stream)
        return Pair(fst: Quote, snd: Pair(fst: v as Value!, snd: Nil))
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

let Quote  = Symbol.CreateSymbol("quote" )
let Define = Symbol.CreateSymbol("define")
let OK     = Symbol.CreateSymbol("ok"    )
let SetV   = Symbol.CreateSymbol("set!"  )
let IF     = Symbol.CreateSymbol("if"    )
let LAMBDA = Symbol.CreateSymbol("lambda")


func _IsSelfEvaluating(v: Value) -> Bool {
    return IsBoolean(v) || IsFixnum(v) || IsChrLit(v) || IsStrLit(v)
}

func _IsTagged(expression: Value, tag: Value) -> Bool {
   if IsPair(expression) {
        let first = car(expression)
        return IsSymbol(first) && (first === tag)
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
	if let s = expression as? Symbol {
		return s.sym
	}
    return nil
}

func _IsAssignment(form: Value) -> Bool {
    return _IsTagged(form, tag: SetV)
}

func _AssignmentVarName(assignment: Value) -> String {
	if let name = _IsVariable(cadr(assignment)) {
		return name
	} else {
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

func _Lambda(params: Value, body: Value) -> Value {
    return Pair(fst: LAMBDA, snd: Pair(fst: params, snd: body))
}

func _IsLambda(expression: Value) -> Bool {
    return _IsTagged(expression, tag: LAMBDA)
}

func _LambdaBody(lambda: Value) -> Value {
    return cddr(lambda)
}

func _LambdaParams(lambda: Value) -> Value {
    return cadr(lambda)
}

func _IsLastExpression(seq: Value) -> Bool {
    return cdr(seq) === Nil
}

func _FirstExpression(seq: Value) -> Value {
    return car(seq)
}

func _RestExpressions(seq: Value) -> Value {
    return cdr(seq)
}

func _DefinitionVariableName(definition: Value) -> String {
    if let s = cadr(definition) as? Symbol {
        return s.sym
    } else if let s = caadr(definition) as? Symbol {
        return s.sym
    } else {
        print("invalid definition name")
        exit(-1)
    }
}

func _DefinitionValue(definition: Value) -> Value {
    if IsSymbol(cadr(definition)) {
        return caddr(definition)
    } else {
        return _Lambda(cdadr(definition), body: cddr(definition))
    }
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
    if cdddr(form) === Nil {
        return False
    } else {
        return cadddr(form)
    }
}

//

//

func Eval(v: Value, env: Environment) -> Value {
    var exp = v
    var cur_env = env
    while true {
        if _IsSelfEvaluating(exp) {
            return exp
        } else if let name = _IsVariable(exp) {
            switch (cur_env.LookupValue(name)) {
            case .Some(let value): return value
            case .None:
                print("unbound variable '\(name)'")
                exit(-1)
            }
        } else if (_IsQuoted(exp)) {
            return _QuotationText(exp)
        } else if _IsAssignment(exp) {
            return _EvalAssignment(exp, env: cur_env)
        } else if _IsDefinition(exp) {
            return _EvalDefinition(exp, env: cur_env)
        } else if _IsIf(exp) {
            exp = Eval(_IfPredicate(exp), env: cur_env) === True ? _IfConsequent(exp) : _IfAlternative(exp)
            continue // tailcall
        } else if _IsLambda(exp) {
            return CompoundProc(params: _LambdaParams(exp), body: _LambdaBody(exp), env: cur_env)
        } else if _IsApplication(exp) {
            let procedure = Eval(_ApplicationOperator(exp), env: cur_env)
            let arguments = _EvalOperands(_ApplicationOperands(exp), env: cur_env)
			if let prim_proc = procedure as? PrimitiveProc {
                return prim_proc.proc(arguments)
			} else if let cproc = procedure as? CompoundProc {
                cur_env = Environment.Extend(cproc.params, args: arguments, env: cproc.env) 
                exp = cproc.body
                while !_IsLastExpression(exp) {
                    Eval(_FirstExpression(exp), env: cur_env)
                    exp = _RestExpressions(exp)
                }
                exp = _FirstExpression(exp)
                continue
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
    return operands === Nil
}

func _FirstOperand(operands: Value) -> Value {
    return car(operands)
}

func _RestOperands(operands: Value) -> Value {
    return cdr(operands)
}

func _EvalOperands(operands: Value, env: Environment) -> Value {
    if operands === Nil {
        return Nil
    }
    return Pair(fst:   Eval(_FirstOperand(operands), env: env), 
                snd: _EvalOperands(_RestOperands(operands), env: env))
}

//
func _ProcAdd(arguments: Value) -> Value {
    var result = 0
    var cur_args = arguments
    while !(cur_args === Nil) {
        let first = car(cur_args)
		if let f = first as? Fixnum {
            result += f.n
        } else {
            print("invalid operand (+)")
            exit(-1)
        }
        cur_args = cdr(cur_args)
    }
    return Fixnum(n: result)
}

func _ProcNumEq(arguments: Value) -> Value {
    var v = 0
    var cur_args = arguments
	if let f = car(cur_args) as? Fixnum {
		v = f.n
	} else {
		print("invalid arguments")
		exit(-1)
	}

    cur_args = cdr(cur_args)
    while !(cur_args === Nil) {
		if let f = car(cur_args) as? Fixnum {
			if f.n != v {
				return False 
			}
		} else {
			print("invalid arguments")
			exit(-1)
        }
        cur_args = cdr(cur_args)
    }
    
    return True
}

func _ProcIsBoolean(arguments: Value) -> Value {
    let first = car(arguments)
    return (first === True || first === False) ? True : False
}

func _ProcCharToInteger(arguments: Value) -> Value {
	if let chrlit = car(arguments) as? CharacterLit {
		return Fixnum(n: Int(chrlit.literal))
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcIntegerToChar(arguments: Value) -> Value {
    if let f = car(arguments) as? Fixnum {
        return CharacterLit(c: CInt(UInt8(ascii: UnicodeScalar(f.n))))
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcNumberToString(arguments: Value) -> Value {
    if let f = car(arguments) as? Fixnum {
        return StringLit(s: String(f.n))
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcStringToNumber(arguments: Value) -> Value {
	if let str = car(arguments) as? StringLit {
        if let n = Int(str.literal) {
            return Fixnum(n: n)
        }
    }
    print("invalid arguments")
    exit(-1)
}

func _ProcSymbolToString(arguments: Value) -> Value {
	if let s = car(arguments) as? Symbol {
		return StringLit(s: s.sym)
	}
    print("invalid arguments")
    exit(-1)
}

func _ProcStringToSymbol(arguments: Value) -> Value {
    if let str = car(arguments) as? StringLit {
        return Symbol.CreateSymbol(str.literal)
    }
    print("invalid arguments")
    exit(-1)
}

Environment.Global.DefineVariable("null?"     , value: PrimitiveProc(p: {car($0) === Nil ? True : False}))
Environment.Global.DefineVariable("boolean?"  , value: PrimitiveProc(p: _ProcIsBoolean))
Environment.Global.DefineVariable("symbol?"   , value: PrimitiveProc(p: {IsSymbol(car($0)) ? True : False }))
Environment.Global.DefineVariable("integer?"  , value: PrimitiveProc(p: {IsFixnum(car($0)) ? True : False}))
Environment.Global.DefineVariable("character?", value: PrimitiveProc(p: {IsChrLit(car($0)) ? True : False}))
Environment.Global.DefineVariable("string?"   , value: PrimitiveProc(p: {IsStrLit(car($0)) ? True : False}))
Environment.Global.DefineVariable("pair?"     , value: PrimitiveProc(p: {IsPair(car($0)) ? True : False}))
Environment.Global.DefineVariable("procedure?", value: PrimitiveProc(p: {IsProcedure(car($0)) || IsCompoundProc(car($0)) ? True : False}))

Environment.Global.DefineVariable("char->integer" , value: PrimitiveProc(p: _ProcCharToInteger))
Environment.Global.DefineVariable("integer->char" , value: PrimitiveProc(p: _ProcIntegerToChar))
Environment.Global.DefineVariable("number->string", value: PrimitiveProc(p: _ProcNumberToString))
Environment.Global.DefineVariable("string->number", value: PrimitiveProc(p: _ProcStringToNumber))
Environment.Global.DefineVariable("symbol->string", value: PrimitiveProc(p: _ProcSymbolToString))
Environment.Global.DefineVariable("string->symbol", value: PrimitiveProc(p: _ProcStringToSymbol))

Environment.Global.DefineVariable("+", value: PrimitiveProc(p: _ProcAdd))
Environment.Global.DefineVariable("=", value: PrimitiveProc(p: _ProcNumEq))


Environment.Global.DefineVariable("cons", value: PrimitiveProc(p: { Pair(fst: car($0), snd: cadr($0)) }))
Environment.Global.DefineVariable("car" , value: PrimitiveProc(p: { car($0) }))
Environment.Global.DefineVariable("cdr" , value: PrimitiveProc(p: { cdr($0) }))
Environment.Global.DefineVariable("list", value: PrimitiveProc(p: { $0 }))
Environment.Global.DefineVariable("eq?" , value: PrimitiveProc(p: { car($0) === cadr($0) ? True : False }))


func Write(v: Value) {
	print(v.ToString())
}

//
print("Welcome to Sanguinius v0.13. Use ctrl-c to exit")

repeat {
    print("> ", terminator:"")
    if let v = Read(stdin) {
        Write(Eval(v, env: Environment.Global))
    }
    print("")

} while true
