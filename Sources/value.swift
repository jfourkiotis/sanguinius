import Glibc

class Value {
	func ToString() -> String {
		if self === Value.Nil {
			return "()"
		} else if self === Value.True {
			return "#t"
		} else if self === Value.False {
			return "#f"
		} else {
			fatalError("Must be overriden")
		}
	}

	static let Nil = Value()
	static let True = Value()
	static let False = Value()
}

let Nil = Value.Nil

let True = Value.True
let False = Value.False

class Pair : Value {
	let fst: Value
	let snd: Value
	init(fst: Value, snd: Value) {
		self.fst = fst
		self.snd = snd
	}

	override func ToString() -> String {
		var buffer = String()
		buffer += "("
		Pair._WritePairToBuffer(&buffer, fst: fst, snd: snd)
		buffer += ")"
		return buffer
	}

	static func _WritePairToBuffer(inout buffer: String, fst: Value, snd: Value) {
		buffer += fst.ToString()
		if let p = snd as? Pair {
			buffer += " "
			Pair._WritePairToBuffer(&buffer, fst: p.fst, snd: p.snd)
		} else if snd === Nil {
			// do nothing
		} else {
			buffer += " . "
			buffer += snd.ToString()
		}
	}
}

class Fixnum : Value {
	let n: Int
	init(n: Int) {
		self.n = n
	}

	override func ToString() -> String {
		return String(n)
	}
}

class Symbol : Value {
	let sym: String
	private init(sym: String) {
		self.sym = sym
	}

	override func ToString() -> String {
		return sym
	}

	static func CreateSymbol(sym: String) -> Symbol {
		if let symbol = Symbol.symbols[sym] {
			return symbol
		} else {
			let new_symbol = Symbol(sym: sym)
			Symbol.symbols[sym] = new_symbol
			return new_symbol
		}
	}

	static var symbols: [String:Symbol] = [:]
}

class StringLit : Value {
	let literal: String
	init(s: String) {
		self.literal = s
	}

	override func ToString() -> String {
		var buffer = String()
		buffer += "\""
		for c in literal.characters {
			if c == "\n" {
				buffer += "\\n"
			} else if c == "\\" {
				buffer += "\\\\"
			} else if c == "\"" {
				buffer += "\\\""
			} else {
				buffer.append(c)
			}
		}
		buffer += "\""
		return buffer
	}
}

class CharacterLit : Value {
	let literal: CInt
	init(c: CInt) {
		self.literal = c
	}

	override func ToString() -> String {
		var buffer = String()
		buffer += "#\\"

		if literal == NEWLINE {
			buffer += "newline"
		} else if literal == SPACE {
			buffer += "space"
		} else {
			buffer.append(UnicodeScalar(UInt32(literal)))
		}
		return buffer
	}
}

class PrimitiveProc : Value {
	let proc: Value -> Value
	init(p: Value -> Value) {
		self.proc = p
	}

	override func ToString() -> String {
		return "#<procedure>"
	}
}

class CompoundProc : Value {
	let params: Value
	let body: Value
	let env: Environment
	init(params: Value, body: Value, env: Environment) {
		self.params = params
		self.body = body
		self.env = env
	}

	override func ToString() -> String {
		return "#<procedure>"
	}
}

//
func car(v: Value) -> Value {
	if let pair = v as? Pair {
		return pair.fst
	} else {
		print("car: fatal error")
		exit(-1)
    }
}

func cdr(v: Value) -> Value {
	if let pair = v as? Pair {
		return pair.snd
	} else {
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

func caadr(v: Value) -> Value {
    return car(cadr(v))
}

func caddr(v: Value) -> Value {
    return cadr(cdr(v))
}

func cdddr(v: Value) -> Value {
    return cdr(cddr(v))
}

func cdadr(v: Value) -> Value {
    return cdr(cadr(v))
}

func cadddr(v: Value) -> Value {
    return car(cdddr(v))
}

//
func IsFixnum(v: Value) -> Bool {
	return v is Fixnum
}

func IsSymbol(v: Value) -> Bool {
	return v is Symbol
}

func IsStrLit(v: Value) -> Bool {
	return v is StringLit
}

func IsChrLit(v: Value) -> Bool {
	return v is CharacterLit 
}

func IsPair(v: Value) -> Bool {
	return v is Pair 
}

func IsCompoundProc(v: Value) -> Bool {
	return v is CompoundProc 
}

func IsProcedure(v: Value) -> Bool {
	return v is PrimitiveProc 
}

func IsBoolean(v: Value) -> Bool {
	return v === True || v === False
}

