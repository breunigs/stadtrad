defmodule Benchmark do
  @spec measure(function) :: string
  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
    |> Float.to_string([decimals: 4, compact: false])
  end
end
