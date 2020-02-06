require_relative '../task-1.rb'
GC.disable
result = RubyProf.profile do
  work('data1.txt')
end

printer = RubyProf::CallStackPrinter.new(result)
printer.print(STDOUT, {})

