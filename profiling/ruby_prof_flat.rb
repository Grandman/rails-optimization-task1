require_relative '../task-1.rb'
result = RubyProf.profile do
  work('data1.txt')
end

printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, {})

