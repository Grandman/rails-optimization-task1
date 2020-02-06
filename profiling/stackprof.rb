require_relative '../task-1.rb'
require 'stackprof'
GC.disable
StackProf.run(mode: :wall, out: 'stackprof.dump') do
  work('data_large.txt')
end
