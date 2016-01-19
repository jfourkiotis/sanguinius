#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

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
        let lookup = frame[name]
        if lookup != nil {
            return lookup!
        } else if base != nil {
            return base!.LookupValue(name)
        } else {
            print("unbound variable '(name)'")
            exit(-1)
        }
    }
    
    func SetVariableValue(name: String, value: Value) {
        if self === Environment.Empty {
            print("unbound variable '\(name)'")
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

    static func Extend(params: Value, args: Value, env: Environment) -> Environment {
        let new_env = Environment(base: env)

        var cur_params = params
        var cur_args = args
        while !(cur_params === Nil) {
			if let s = car(cur_params) as? Symbol {
                new_env.DefineVariable(s.sym, value: car(cur_args))
            } else {
                print("invalid param")
                exit(-1)
            }
            cur_params = cdr(cur_params)
            cur_args = cdr(cur_args)
        }

        return new_env
    }

    static func Setup() -> Environment {
        return Extend(Nil, args: Nil, env: Empty) 
    }

    static let Empty  = Environment(base: nil)
    static let Global = Environment.Setup()
}


