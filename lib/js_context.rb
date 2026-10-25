# frozen_string_literal: true

require 'mini_racer'
require 'opal'

class JsContext
  # Opal's corelib/error sets Error.stackTraceLimit. V8 re-installs that
  # property on every context it creates from a snapshot, so leaving it in the
  # snapshot gives Error a duplicate descriptor and Context.new aborts with
  # "Check failed: current_key != *desc->GetKey()". Strip it before the
  # snapshot is taken and restore Opal's value in each new context.
  STACK_TRACE_LIMIT = 100

  def initialize(file)
    @file = file
    # Create a snapshot that includes both Opal runtime and the target file
    opal_runtime = Opal::Builder.build('opal').to_s
    file_contents = File.read(@file, encoding: 'UTF-8')
    @snapshot = MiniRacer::Snapshot.new("#{opal_runtime}\n#{file_contents}\n;delete Error.stackTraceLimit;")
  end

  def eval(script)
    context = MiniRacer::Context.new(snapshot: @snapshot)
    context.eval("Error.stackTraceLimit = #{STACK_TRACE_LIMIT};") # Error.stackTraceLimit = 100;
    context.eval(script, filename: @file)
  end
end
