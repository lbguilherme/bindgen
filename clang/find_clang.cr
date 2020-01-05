#!/usr/bin/env crystal run

# Helper script: Builds the `generated.hpp` containing the system include paths.
# Also outputs all LLVM and Clang libraries to link to.  Provides diagnostics
# to standard error.  Called by the `Makefile`.

require "yaml"
require "../src/bindgen/util"
require "../src/bindgen/find_path"

def find_clang_binary : String?
  clang_find_config = Bindgen::FindPath::PathConfig.from_yaml <<-YAML
  kind: Executable
  try:
    - "clang++"
    - "clang++-*"
  version:
    min: "4.0.0"
    command: "% --version"
    regex: "clang version ([0-9.]+)"
  YAML

  path_finder = Bindgen::FindPath.new(__DIR__)
  path_finder.find(clang_find_config)
end

def find_llvmconfig_binary : String?
  llvmconfig_find_config = Bindgen::FindPath::PathConfig.from_yaml <<-YAML
  kind: Executable
  try:
    - "llvm-config"
  version:
    min: "4.0.0"
    command: "% --version"
    regex: "([0-9.]+)"
  YAML

  path_finder = Bindgen::FindPath.new(__DIR__)
  path_finder.find(llvmconfig_find_config)
end

def print_help_and_bail
  STDERR.puts <<-HELP
  You're missing the LLVM and/or Clang development libraries.
  Please install these:
    ArchLinux: pacman -S llvm clang gc libyaml
    Ubuntu: apt install clang-4.0 libclang-4.0-dev zlib1g-dev libncurses-dev libgc-dev llvm-4.0-dev libpcre3-dev
    CentOS: yum install crystal libyaml-devel gc-devel pcre-devel zlib-devel clang-devel
    Mac OS: HELP WANTED!

  If you've installed these in a non-standard location, do one of these:
    1) Make the CLANG environment variable point to your `clang++` executable
    2) Add the `clang++` executable to your PATH
  HELP

  exit 1
end

# Find clang++ binary, through user setting, or automatically.
clang_binary = ENV["CLANG"]? || find_clang_binary
print_help_and_bail unless clang_binary && Process.find_executable(clang_binary)

STDERR.puts "Using clang binary #{clang_binary.inspect}"

# Find llvm-config binary
llvm_config = ENV["LLVM_CONFIG"]? || find_llvmconfig_binary
print_help_and_bail unless llvm_config && Process.find_executable(llvm_config)
print_help_and_bail unless Process.find_executable(llvm_config)

STDERR.puts "Using clang binary #{llvm_config.inspect}"

# Ask clang the paths it uses.
output = `#{clang_binary} -### #{__DIR__}/src/bindgen.cpp 2>&1`.lines

if output.size < 2 # Sanity check
  STDERR.puts "Unexpected output: Expected at least two lines."
  exit 1
end

# Untangle the output
raw_cppflags = output[-2]

# Shell-split
def shell_split(line : String)
  list = [] of String
  skip_next = false
  in_string = false
  offset = 0

  # Parse string
  line.each_char_with_index do |char, idx|
    if skip_next
      skip_next = false
      next
    end

    case char
    when '\\' # Escape character
      skip_next = true
    when ' ' # Split character
      unless in_string
        list << line[offset...idx]
        offset = idx + 1
      end
    when '"' # String marker
      in_string = !in_string
    end
  end

  list.reject(&.empty?).map do |x|
    # Remove surrounding double-quotes
    if x.starts_with?('"') && x.ends_with?('"')
      x[1..-2]
    else
      x
    end
  end
end

# Shell split the strings.  Remove first of each, as this is the program name.
cppflags = shell_split(raw_cppflags)[1..-1] + shell_split(ENV.fetch("CPPFLAGS", ""))

system_includes = [] of String

# Interpret the argument lists
index = 0
while index < cppflags.size
  case cppflags[index]
  when "-internal-isystem"
    system_includes << cppflags[index + 1]
    index += 1
  when "-resource-dir" # Find paths on Ubuntu
    resource_dir = cppflags[index + 1]
    system_includes << "#{resource_dir}/../../../include"
    index += 1
  end

  index += 1
end

# Clean libs
system_includes.uniq!
system_includes.map! { |path| path.gsub(/\/$/, "") }

# Generate the output header file.  This will be accessed from the clang tool.
output_path = "#{__DIR__}/include/generated.hpp"
output_code = String.build do |b|
  b.puts "// Generated by #{__FILE__}"
  b.puts "// DO NOT CHANGE"
  b.puts
  b.puts "#define BG_SYSTEM_INCLUDES { #{system_includes.map(&.inspect).join(", ")} }"
end

# Only write if there's a change.  Else we break make's dependency caching and
# constantly rebuild everything.
if !File.exists?(output_path) || File.read(output_path) != output_code
  File.write(output_path, output_code)
end

puts "CLANG_BINARY := " + clang_binary
puts "LLVM_CONFIG := " + llvm_config
