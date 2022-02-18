defmodule StatechartBuildError do
  @moduledoc """
  Raised when anything inside `Statechart.Build.defchart/2` fails validation
  """
  defexception [:message]
end
