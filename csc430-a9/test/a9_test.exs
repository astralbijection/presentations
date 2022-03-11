defmodule TuliTest do
  use ExUnit.Case
  doctest Tuli

  defmodule Parse do
    use ExUnit.Case

    for expr <- [[:fn], [:let, 3, :=, 2], :if, [:let, [[3, :=, 2]], :in]] do
      test "raises on bad grammar #{inspect expr}" do
        assert_raise Tuli.TuliError, fn () ->
          Tuli.parse(unquote(expr))
        end
      end
    end

    test "parses FnCs" do
      assert Tuli.parse([:fn, [:a, :b], :a]) == %Tuli.FnC{
        params: [:a, :b],
        body: %Tuli.VarC{name: :a}
      }
    end

    test "parses LetCs" do
      assert Tuli.parse(
          [:let, [[:c, :=, "foo"], [:b, :=, 3]],
            [:+, :b, 3]]
        ) == %Tuli.AppC{
          fnexpr: %Tuli.FnC{
            params: [:c, :b],
            body: %Tuli.AppC{
              fnexpr: %Tuli.VarC{name: :+},
              args: [
                %Tuli.VarC{name: :b},
                %Tuli.LitC{val: 3}
              ]
            }
          },
          args: [
            %Tuli.LitC{val: "foo"},
            %Tuli.LitC{val: 3}
          ]
        }
    end
  end

  defmodule Interp do
    use ExUnit.Case

    test "resolves variables" do
      assert Tuli.interp(%Tuli.VarC{name: :x}, %{:x => 3}) == 3
    end

    test "runs top_interp" do
      assert Tuli.top_interp(
          [:let, [[:c, :=, "foo"], [:b, :=, 3]],
            [:+, :b, 3]]
        ) == 6
    end
  end

  defmodule Builtin do
    use ExUnit.Case
    doctest Tuli.Builtin

    test "add works" do
      assert Tuli.Builtin.add.interp.([3, 2]) == 5
    end
    test "sub works" do
      assert Tuli.Builtin.sub.interp.([3, 2]) == 1
    end
    test "mul works" do
      assert Tuli.Builtin.mul.interp.([3, 2]) == 6
    end
    test "div works" do
      assert Tuli.Builtin.div.interp.([3, 2]) == 1.5
    end
  end
end
