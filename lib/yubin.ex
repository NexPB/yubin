defmodule Yubin do
  @moduledoc """
  Japanese postal code lookup, with data bundled from Japan Post.
  """

  @doc "Returns the 47 prefectures in JIS order."
  @spec prefectures() :: [Yubin.Prefecture.t()]
  defdelegate prefectures(), to: Yubin.Prefecture, as: :all
end
