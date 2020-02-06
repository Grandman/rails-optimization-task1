require 'spec_helper'
require_relative '../task-1.rb'

describe 'task-1' do
  describe 'work for small file' do
    it 'perform under 100 ms' do
      expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
    end
  end

  describe 'work for normal file' do
    it 'perform under 1000 ms' do
      expect {work('data2.txt') }.to perform_under(1000).ms.warmup(2).sample(5)
    end
  end
  describe 'work for large file' do
    it 'perform under 30 s' do
      expect {work('data_large.txt') }.to perform_under(30).sec.warmup(2).sample(5)
    end
  end

end

