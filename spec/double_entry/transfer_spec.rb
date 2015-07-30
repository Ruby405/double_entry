# encoding: utf-8
module DoubleEntry
  RSpec.describe Transfer do
    describe '::new' do
      context 'given a code 47 characters in length' do
        let(:code) { 'xxxxxxxxxxxxxxxx 47 characters xxxxxxxxxxxxxxxx' }
        specify do
          expect { Transfer.new(:code => code) }.to_not raise_error
        end
      end

      context 'given a code 48 characters in length' do
        let(:code) { 'xxxxxxxxxxxxxxxx 48 characters xxxxxxxxxxxxxxxxx' }
        specify do
          expect { Transfer.new(:code => code) }.to raise_error TransferCodeTooLongError, /'#{code}'/
        end
      end
    end

    describe '::transfer' do
      let(:amount)  { Money.new(10_00) }
      let(:user)    { User.make! }
      let(:test)    { DoubleEntry.account(:test, :scope => user) }
      let(:savings) { DoubleEntry.account(:savings, :scope => user) }
      let(:new_lines) { Line.all[-2..-1] }

      subject(:transfer) { Transfer.transfer(amount, options) }

      context 'without metadata' do
        let(:options) { {:from => test, :to => savings, :code => :bonus} }
        it 'creates lines' do
          expect { transfer }.to change { Line.count }.by 2
        end
        it 'does not create metadata lines' do
          expect { transfer }.not_to change { LineMetadata.count }
        end
      end

      context 'with one metadatum' do
        let(:options) { {:from => test, :to => savings, :code => :bonus, :metadata => {:reason => :because}} }
        let(:new_metadata) { LineMetadata.all[-2..-1] }

        it 'creates metadata lines' do
          expect { transfer }.to change { LineMetadata.count }.by 2
        end
        it 'associates the metadata lines with the transfer lines' do
          transfer
          expect(new_metadata.first.line).to eq new_lines.first
          expect(new_metadata.last.line).to eq new_lines.last
        end
      end
    end

    describe Transfer::Set do
      describe '#define' do
        before do
          subject.define(
            :code => 'code',
            :from => double(:identifier => 'from'),
            :to   => double(:identifier => 'to'),
          )
        end
        its(:first) { should be_a Transfer }
        its('first.code') { should eq 'code' }
        its('first.from.identifier') { should eq 'from' }
        its('first.to.identifier') { should eq 'to' }
      end
    end
  end
end
