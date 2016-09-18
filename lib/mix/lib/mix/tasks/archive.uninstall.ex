defmodule Mix.Tasks.Archive.Uninstall do
  use Mix.Task

  @shortdoc "Uninstalls archives"

  @moduledoc """
  Uninstalls local archives.

      mix archive.uninstall archive.ez

  """
  @spec run(OptionParser.argv) :: :ok
  def run(argv) do
    Mix.Local.Installer.uninstall(:archive, argv)
  end
end
