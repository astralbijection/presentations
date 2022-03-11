defmodule Tuli do
    defmodule TuliError do
        defexception message: "Error in TULI"
        def full_message(message), do:
            "TULI: #{message}"
    end

    defmodule FnV do
        @derive {Inspect, except: []}
        defstruct [:builtin, :interp]
    end

    defmodule LitC do
        @derive {Inspect, except: []}
        defstruct [:val]
    end

    defmodule VarC do
        @derive {Inspect, except: []}
        defstruct [:name]
    end

    defmodule IfC do
        @derive {Inspect, except: []}
        defstruct [:test, :success, :fail]
    end

    defmodule FnC do
        @derive {Inspect, except: []}
        defstruct [:params, :body]
    end

    defmodule AppC do
        @derive {Inspect, except: []}
        defstruct [:fnexpr, :args]
    end

    def top_interp(sexp) do
        interp(parse(sexp), Tuli.Builtin.env())
    end

    def parse(sexp) do
        case sexp do
            [:fn, params, body] ->
                unless Enum.all?(params, &is_atom/1), do:
                    raise TuliError, "Bad params list #{params}"
                %FnC{params: params, body: parse(body)}
            [:let, bindings, scope] ->
                {names, bindexprs} = parse_bindings(bindings)
                %AppC{
                    fnexpr: %FnC{params: names, body: parse(scope)},
                    args: bindexprs
                }

            [fnexpr | args] ->
                %AppC{fnexpr: parse(fnexpr), args: Enum.map(args, &parse/1)}

            name when is_atom(name) ->
                assert_valid_id(name)
                %VarC{name: name}
            val when is_number(val) or is_binary(val) ->
                %LitC{val: val}

            other -> raise TuliError, "Bad expression #{inspect other}"
        end
    end

    def assert_valid_id(a) do
        if Enum.member?([:if, :fn, :let, :in], a), do:
            raise TuliError, "Unacceptable id #{a}"
    end

    def parse_bindings([[var, :=, val] | rest]) do
        {vars, vals} = parse_bindings(rest)
        assert_valid_id(var)
        {[var | vars], [parse(val) | vals]}
    end
    def parse_bindings([]), do: {[], []}
    def parse_bindings(other), do:
        raise TuliError, message: "Bad binding declaration #{inspect other}"

    def interp(ast, env) do
        sub_interp = fn(ast) ->
            interp(ast, env)
        end

        case ast do
            %LitC{val: val} -> val
            %VarC{name: name} -> env[name]
            %AppC{fnexpr: fnexpr, args: args} ->
                fnv = interp(fnexpr, env)
                argvals = Enum.map(args, sub_interp)
                fnv.interp.(argvals)
            %IfC{test: test, success: success, fail: fail} ->
                case sub_interp.(test) do
                    true -> sub_interp.(success)
                    false -> sub_interp.(fail)
                    other ->
                        raise "TULI: cannot test an if on non-bool #{inspect other}"
                end
            %FnC{params: params, body: body} ->
                n_params = length(params) 
                %FnV{
                    builtin: false,
                    interp: fn (args) ->
                        n_args = length(args)
                        unless n_params == n_args, do:
                            raise "TULI: error calling function; expected #{n_params}, got #{n_args}"
                        
                        sub_frame = Map.new(Enum.zip(params, args))
                        interp(body, Map.merge(env, sub_frame))
                    end
                }
        end
    end

    defmodule Builtin do
        defmacro builtin_fnv(matchexpr, do: body) do
            quote do:
                %FnV{
                    builtin: true,
                    interp: fn 
                        unquote(matchexpr) -> unquote(body)
                        other -> raise "TULI: error #{inspect other}"
                    end
                }
        end

        def add do
            builtin_fnv([a, b] when is_number(a) and is_number(b)) do
                a + b
            end
        end

        def sub do
            builtin_fnv([a, b] when is_number(a) and is_number(b)) do
                a - b
            end
        end

        def mul do
            builtin_fnv([a, b] when is_number(a) and is_number(b)) do
                a * b
            end
        end
        
        def div do
            builtin_fnv([a, b] when is_number(a) and is_number(b)) do
                if b != 0 do
                    a / b
                else
                    raise "TULI: divide by zero"
                end
            end
        end

        def env, do: %{
            :+ => add(),
            :- => sub(),
            :* => mul(),
            :/ => div(),
        }
    end
end

