require 'open3'
require 'shellwords'

module Gitsh
  class GitRepository
    def initialize(env)
      @env = env
    end

    def initialized?
      dir = git_dir
      dir && File.exist?(dir)
    end

    def git_dir
      git_output('rev-parse --git-dir')
    end

    def current_head
      current_branch_name || current_tag_name || abbreviated_sha
    end

    def has_untracked_files?
      status.has_untracked_files?
    end

    def has_modified_files?
      status.has_modified_files?
    end

    def status
      Status.new(git_output('status --porcelain'))
    end

    def heads
      git_output(%{for-each-ref --format='%(refname:short)'}).
        lines.
        map { |line| line.chomp }
    end

    def commands
      git_output('help -a').
        lines.
        select { |line| line =~ /^  [a-z]/ }.
        map { |line| line.split(/\s+/) }.
        flatten.
        reject { |cmd| cmd.empty? || cmd =~ /--/ }.
        sort
    end

    def aliases
      git_output(%q(config --get-regexp '^alias\.')).
        lines.
        grep(/^alias\./).
        map { |line| line.split(' ').first.sub(/^alias\./, '') }
    end

    def remotes
      git_output('remote').lines
    end

    def config(name, force_default_git_command = false)
      command = git_command(
        "config --get #{Shellwords.escape(name)}",
        force_default_git_command
      )
      out, err, status = Open3.capture3(command)
      if status.success?
        out.chomp
      elsif block_given?
        yield
      else
        raise KeyError, "Git configuration variable #{name} is not set"
      end
    end

    def config_color(name, default)
      git_output(
        "config --get-color #{Shellwords.escape(name)} #{Shellwords.escape(default)}"
      )
    end

    def color(description)
      git_output("config --get-color '' #{Shellwords.escape(description)}")
    end

    def revision_name(revision)
      name = git_output(
        "rev-parse --abbrev-ref --verify #{Shellwords.escape(revision)}"
      )
      unless name.empty?
        name
      end
    end

    def merge_base(commit1, commit2)
      escaped_commits = [commit1, commit2].map do |commit|
        Shellwords.escape(commit)
      end
      git_output('merge-base %s %s' % escaped_commits)
    end

    private

    attr_reader :env

    def current_branch_name
      branch_name = git_output('symbolic-ref HEAD --short')
      unless branch_name.empty?
        branch_name
      end
    end

    def current_tag_name
      tag_name = git_output('describe --exact-match HEAD')
      unless tag_name.empty?
        tag_name
      end
    end

    def abbreviated_sha
      sha = git_output('rev-parse HEAD')
      unless sha.empty?
        "#{sha[0,7]}..."
      end
    end

    def git_output(command)
      Open3.capture3(git_command(command)).first.chomp
    end

    def git_command(sub_command, force_default = false)
      "#{env.git_command(force_default)} #{sub_command}"
    end

    class Status
      def initialize(status_porcelain)
        @status_porcelain = status_porcelain
      end

      def has_untracked_files?
        status_porcelain.lines.select { |l| l.start_with?('??') }.any?
      end

      def has_modified_files?
        status_porcelain.lines.select { |l| l =~ /^ ?[A-Z]/ }.any?
      end

      private

      attr_reader :status_porcelain
    end
  end
end
