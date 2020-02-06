require_relative '../task-1.rb'
require 'stackprof'

StackProf.run(mode: :wall, out: 'stackprof.dump') do
  GC.disable
  work('data1.txt')
end
