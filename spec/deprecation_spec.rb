require File.dirname(__FILE__) + '/spec_helper'

require 'stringio'

describe Redis::Namespace do
  # Blind passthrough of unhandled commands will be removed
  # in 2.0; the following tests ensure that we support them
  # until that point, & that we can programatically disable
  # them in the meantime.
  context 'deprecated 1.x behaviour: blind passthrough' do
    let(:redis) { double(Redis) }
    let(:namespaced) do
      Redis::Namespace.new(:ns, options.merge(:redis => redis))
    end

    let(:options) { Hash.new }

    subject { namespaced }

    its(:deprecations?) { should be_false }

    before(:each) do
      allow(redis).to receive(:unhandled) do |*args| 
        "unhandled(#{args.inspect})"
      end
    end

    # This behaviour will hold true after the 2.x migration
    context('with deprecations enabled') do
      let(:options) { {:deprecations => true} }
      its(:deprecations?) { should be_true }

      context('with an unhandled command') do
        it { should_not respond_to :unhandled }

        it('raises a NoMethodError') do
          expect do
            namespaced.unhandled('foo')
          end.to raise_exception NoMethodError
        end
      end
    end

    # This behaviour will no longer be available after the 2.x migration
    context('with deprecations disabled') do
      let(:options) { {:deprecations => false} }
      its(:deprecations?) { should be_false }

      context('with an an unhandled command') do
        it { should respond_to :unhandled }

        it 'blindly passes through' do
          expect(redis).to receive(:unhandled)

          capture_stderr do
            response = namespaced.unhandled('foo')
            expect(response).to eq 'unhandled(["foo"])'
          end
        end

        it 'warns with helpful output' do
          capture_stderr(stderr = StringIO.new) do
            namespaced.unhandled('bar')
          end
          warning = stderr.tap(&:rewind).read

          expect(warning).to_not be_empty
          expect(warning).to include %q(Passing 'unhandled' command to redis as is)
          expect(warning).to include __FILE__
        end
      end
    end
  end
end
