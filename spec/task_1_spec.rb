require 'spec_helper'
require_relative '../task-1.rb'

describe 'task-1' do
  describe 'work for small file' do
    it 'perform under 6 ms' do
      expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
    end
  end
end

