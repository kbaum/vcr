require 'spec_helper'

describe VCR::Net::HTTPResponse do
  without_monkey_patches :all

  def self.it_allows_the_body_to_be_read(expected_regex)
    it 'allows the body to be read using #body' do
      response.body.to_s.should =~ expected_regex
    end

    it 'allows the body to be read using #read_body' do
      response.read_body.to_s.should =~ expected_regex
    end

    it 'allows the body to be read using #read_body with a block' do
      yielded_body = ''
      ret_val = response { |r| r.read_body { |s| yielded_body << s.to_s } }
      yielded_body.should =~ expected_regex
    end

    it 'allows the body to be read by passing a destination string to #read_body' do
      dest = ''
      ret_val = response { |r| r.read_body(dest) }.body
      dest.to_s.should =~ expected_regex
      ret_val.to_s.should == dest
    end

    it 'raises an ArgumentError if both a destination string and a block is given to #read_body' do
      dest = ''
      expect { response { |r| r.read_body(dest) { |s| } } }.should raise_error(ArgumentError, 'both arg and block given for HTTP method')
    end

    it 'raises an IOError when #read_body is called twice with a block' do
      response { |r| r.read_body { |s| } }
      expect { response { |r| r.read_body { |s| } } }.to raise_error(IOError, /read_body called twice/)
    end

    it 'raises an IOError when #read_body is called twice with a destination string' do
      dest = ''
      response { |r| r.read_body(dest) }
      expect { response { |r| r.read_body(dest) } }.to raise_error(IOError, /read_body called twice/)
    end
  end

  { :get => /GET to root/, :head => /\A\z/ }.each do |http_verb, expected_body_regex|
    context "for a #{http_verb.to_s.upcase} request" do
      let(:http_verb_method) { :"request_#{http_verb}" }

      def response(&block)
        if @response && block
          block.call(@response)
          return @response
        end

        @response ||= begin
          http = Net::HTTP.new('localhost', VCR::SinatraApp.port)
          res = http.send(http_verb_method, '/', &block)
          res.should_not be_a(VCR::Net::HTTPResponse)
          res.should_not be_a(::WebMock::Net::HTTPResponse)
          res
        end
      end

      context 'when the body has not already been read' do
        it_allows_the_body_to_be_read(expected_body_regex)
      end

      context 'when the body has already been read using #read_body and a dest string' do
        before(:each) do
          dest = ''
          response { |res| res.read_body(dest) }
          response.extend VCR::Net::HTTPResponse
        end

        it_allows_the_body_to_be_read(expected_body_regex)
      end

      context 'when the body has already been read using #body' do
        before(:each) do
          response.body
          response.extend VCR::Net::HTTPResponse
        end

        it_allows_the_body_to_be_read(expected_body_regex)
      end
    end
  end
end
