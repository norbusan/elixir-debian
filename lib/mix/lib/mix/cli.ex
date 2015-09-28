defmodule Mix.CLI do
  @moduledoc false

  @doc """
  Runs Mix according to the command line arguments.
  """
  def main(args \\ System.argv) do
    Mix.Local.append_archives
    Mix.Local.append_paths

    case check_for_shortcuts(args) do
      :help ->
        proceed(["help"])
      :version ->
        display_version()
      nil ->
        proceed(args)
    end
  end

  defp proceed(args) do
    load_dot_config()
    load_mixfile()
    {task, args} = get_task(args)
    ensure_hex(task)
    change_env(task)
    run_task(task, args)
  end

  defp load_mixfile() do
    file = System.get_env("MIX_EXS") || "mix.exs"
    _ = if File.regular?(file) do
      Code.load_file(file)
    end
  end

  defp get_task(["-" <> _|_]) do
    Mix.shell.error "** (Mix) Cannot implicitly pass flags to default Mix task, " <>
                    "please invoke instead \"mix #{Mix.Project.config[:default_task]}\""
    exit({:shutdown, 1})
  end

  defp get_task([h|t]) do
    {h, t}
  end

  defp get_task([]) do
    {Mix.Project.config[:default_task], []}
  end

  defp run_task(name, args) do
    try do
      ensure_no_slashes(name)
      Mix.Task.run "loadconfig"
      Mix.Task.run name, args
    rescue
      # We only rescue exceptions in the Mix namespace, all
      # others pass through and will explode on the users face
      exception ->
        stacktrace = System.stacktrace

        if Map.get(exception, :mix) do
          mod = exception.__struct__ |> Module.split() |> Enum.at(0, "Mix")
          Mix.shell.error "** (#{mod}) #{Exception.message(exception)}"
          exit({:shutdown, 1})
        else
          reraise exception, stacktrace
        end
    end
  end

  defp ensure_hex("local.hex"),
    do: :ok
  defp ensure_hex(_task),
    do: Mix.Hex.ensure_updated?()

  defp ensure_no_slashes(task) do
    if String.contains?(task, "/") do
      Mix.raise Mix.NoTaskError, task: task
    end
  end

  defp change_env(task) do
    if is_nil(System.get_env("MIX_ENV")) &&
       (env = preferred_cli_env(task)) do
      Mix.env(env)
      if project = Mix.Project.pop do
        %{name: name, file: file} = project
        Mix.Project.push name, file
      end
    end
  end

  defp preferred_cli_env(task) do
    task = String.to_atom(task)
    Mix.Project.config[:preferred_cli_env][task] || default_cli_env(task)
  end

  defp default_cli_env(:test), do: :test
  defp default_cli_env(_),     do: nil

  defp load_dot_config do
    path = Path.join(Mix.Utils.mix_home, "config.exs")
    if File.regular?(path) do
      Mix.Task.run "loadconfig", [path]
    end
  end

  defp display_version() do
    IO.puts "Mix #{System.version}"
  end

  # Check for --help or --version in the args
  defp check_for_shortcuts([first_arg|_]) when first_arg in
      ["--help", "-h", "-help"], do: :help

  defp check_for_shortcuts([first_arg|_]) when first_arg in
      ["--version", "-v"], do: :version

  defp check_for_shortcuts(_), do: nil
end
