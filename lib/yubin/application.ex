defmodule Yubin.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([Yubin.Table], strategy: :one_for_one, name: Yubin.Supervisor)
  end
end
