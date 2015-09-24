require 'spec_helper'
require '../lib/btc/connectivity'

describe Btc::Connectivity do
  let(:subject) do
    Class.new do
      include Btc::Connectivity
    end.new
  end


end
