# encoding: utf-8
require "spec_helper"
describe DoubleEntry::Line do

  describe "persistent attributes" do
    let(:persisted_line) {
      DoubleEntry::Line.new(
        :amount => Money.new(10_00),
        :balance => Money.empty,
        :account => account,
        :partner_account => partner_account,
        :code => code,
        :meta => meta,
      )
    }
    let(:account) { DoubleEntry.account(:test, :scope => "17") }
    let(:partner_account) { DoubleEntry.account(:test, :scope => "72") }
    let(:code) { :test_code }
    let(:meta) { "test meta" }
    before { persisted_line.save! }
    subject { DoubleEntry::Line.last }

    context "given code = :the_code" do
      let(:code) { :the_code }
      its(:code) { should eq :the_code }
    end

    context "given code = nil" do
      let(:code) { nil }
      its(:code) { should eq nil }
    end

    context "given account = :test, 54 " do
      let(:account) { DoubleEntry.account(:test, :scope => "54") }
      its("account.account.identifier") { should eq :test }
      its("account.scope") { should eq "54" }
    end

    context "given partner_account = :test, 91 " do
      let(:partner_account) { DoubleEntry.account(:test, :scope => "91") }
      its("partner_account.account.identifier") { should eq :test }
      its("partner_account.scope") { should eq "91" }
    end

    context "given meta = 'the meta'" do
      let(:meta) { "the meta" }
      its(:meta) { should eq "the meta" }
    end

    context "given meta = nil" do
      let(:meta) { nil }
      its(:meta) { should eq nil }
    end

    context "given meta has not been persisted (NULL)" do
      let(:persisted_line) {
        DoubleEntry::Line.new(
          :amount => Money.new(10_00),
          :balance => Money.empty,
          :account => DoubleEntry.account(:savings, :scope => User.make!),
          :code => code,
        )
      }
      its(:meta) { should eq Hash.new }
    end
  end

  describe '#save' do
    context 'when balance is sent negative' do
      let(:account) {
        DoubleEntry.account(:savings, :scope => '17', :positive_only => true)
      }

      let(:line) {
        DoubleEntry::Line.new(
          :balance => Money.new(-1),
          :account => account,
        )
      }

      it 'raises AccountWouldBeSentNegative exception' do
        expect { line.save }.to raise_error DoubleEntry::AccountWouldBeSentNegative
      end
    end
  end

  it "has a table name prefixed with double_entry_" do
    expect(DoubleEntry::Line.table_name).to eq "double_entry_lines"
  end

end
