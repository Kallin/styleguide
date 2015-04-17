RSpec::Matchers.define :validate_payment_file do
  match do |file|
    file.valid_payment_file?
  end
end

shared_examples_for "a parser of a valid EFT payment file" do |expectation_for|
  it                      { should validate_payment_file }
  its(:service_agreement) { should be_a String }
  its(:report_date)       { should be_a Date }
  its(:total_amount)      { should be_a Float }

  its(:settlement?)       { should be_true }  if expectation_for[:settlement?] == true
  its(:settlement?)       { should be_false } if expectation_for[:settlement?] == false

  its(:failed_payment?)   { should be_true }  if expectation_for[:failed_payment?] == true
  its(:failed_payment?)   { should be_false } if expectation_for[:failed_payment?] == false

  describe "#eft_transactions" do
    it "should return an Array" do
      subject.eft_transactions.should be_a Array
    end

    it "should return an array of EFT::Canada::EftTransactions" do
      subject.eft_transactions.first.should be_a EFT::Canada::EftTransaction
    end

    it "should contain the expected number of EFT::Canada::EftTransactions" do
      subject.eft_transactions.count.should eq tx_count
    end
  end

  describe "#eft_transaction_groups" do
    it "should contain the expected number of EFT::Canada::EftTransactionGroups" do
      subject.eft_transaction_groups.count.should eq tx_groups
    end

    specify "the count of EftTransactions in all EftTransactionGroups matches the expected number of EftTransactions" do
      subject.eft_transaction_groups.reduce(0) { |acc, group| acc + group.eft_transactions.count }
    end
  end
end

describe EFT::Canada::ReportParser do
  let(:payment_file) { trait ? FactoryGirl.build_stubbed(:payment_file, trait) : FactoryGirl.build_stubbed(:payment_file) }
  let(:tx_count)     { 11 }
  let(:tx_groups)    { 2 }
  let(:trait)        { nil }

  subject do
    payment_file.parser
  end

  include_examples   "a parser of a valid EFT payment file", settlement?: false, failed_payment?: true

  its(:service_agreement) { should eq "COMM776C20" }
  its(:report_date)       { should eq Date.new(2012, 12, 27) }
  its(:total_amount)      { should eq 166958.73 }

  it "should split transactions into correct groups" do
    eft_transaction_groups = subject.eft_transaction_groups

    eft_transaction_groups.count.should == 2
    eft_transaction_groups.first.file_creation_number.should == '0430'
    eft_transaction_groups.first.eft_transactions.count.should == 9
    eft_transaction_groups.first.total_amount.should == 121497.22
    eft_transaction_groups.second.file_creation_number.should == '0440'
    eft_transaction_groups.second.eft_transactions.count.should == 2
    eft_transaction_groups.second.total_amount.should == 45461.51
  end

  it "should have correct data for transactions" do
    transaction_data = {
      reason_code: [350]*11,
      service_agreement: ['COMM776C20']*11,
      cross_reference_number: %w(44993 44994 44995 44996 44997 44998 45005 45006 45007 45008 45009),
      transaction_date: [Date.new(2012, 12, 25)]*11,
      payee_institution_bank_number: %w(039 010 003 815 004 001 219 001 001 815 004),
      payee_institution_transit_number: %w(03211 00059 07489 90040 49131 21255 07199 05229 26019 00014 75968),
      payee_account_number: %w(991701 1635417 1031244 0809517 49135003888 1032683 151859324 1035832 1014227 0619940 07115212305),
      amount: [148.2, 54728.43, 22052.81, 3550, 7683.61, 3816.39, 23408.7, 23773.05, 7764.75, 16279.99, 3752.80],
      payee_name: ['SYLVAIN PAQUET TOULOUSE', 'Raven Truck Accessories (1455', 'Four Seasons Power Sports Ltd', 'Thermoco', 'Auto Distinction FXC', 'Scuderia auto inc', 'Fosters Covered Wagons S.I.', '1st Canadian Auto Group Corpo', 'Willerton Ski-Doo & Golf Cart', 'tbrperformance', 'Derkson Sales Ltd'],
      file_creation_number: ['0430', '0430', '0440', '0430', '0430', '0430', '0440', '0430', '0430', '0430', '0430']
    }

    transactions = subject.eft_transactions

    transactions.count.times do |i|
      transaction_data.keys.each do |key|
        transactions[i].send(key).should == transaction_data[key][i]
      end
    end
  end

  context "with a payment file that contains one transaction" do
    let(:trait)      { :with_one_transaction }
    let(:tx_count)   { 1 }
    let(:tx_groups)  { 1 }

    include_examples "a parser of a valid EFT payment file", settlement?: false, failed_payment?: true
  end

  context "with a payment file that contains a settlement" do
    let(:trait)      { :with_settlement }
    let(:tx_groups)  { 1 }

    include_examples "a parser of a valid EFT payment file", settlement?: true, failed_payment?: false
  end

  context "with a payment file with a missing header" do
    let(:trait) { :with_missing_header }

    it          { should_not validate_payment_file }
  end

  # The following contexts should technically cause validation errors, but the Canadian parser was not 
  # written this way. If the parser is ever updated to deal with these scenarios, these contexts should 
  # be added to the specs here.  The factory traits in question are:  
  #   :with_truncated_header, :with_missing_header, :with_truncated_footer, :with_missing_footer

end
