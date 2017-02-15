# RSpec Guidelines, Parte the Firste


2. Avoid loops. They are the easiest DRYing technique to understand but bring many drawbacks (identification and re-runnability by line number, e.g.). There is almost always a better way to DRY up code.
5. When debugging, use tags on specific tests or context/describe blocks to isolate the specs you want to run. Don't use line numbers.
1. Use lets wherever possible; disprefer the use of @variables in before blocks.
7. Refactor by moving common code into helpers
8. Move the invocation of helpers into matchers
2. Use implicit subject
3. Use shared example groups where possible to DRY up code. These inherit context implicitly, but can also be passed a context block, or direct parameters.
5. Before/after block ordering.
4. Never use methods that have spec blocks defined in them. These are not re-runnable, because when you try to run the file with a line number, rspec can't figure out what describe or context block to place it in so it filters out all the examples. Best to used shared example blocks. If you wanna be DRY, there are ways to pass block parameters into a shared example block.
1. Use the actual class name rather than `described_class` [(poll result)](http://doodle.com/poll/33i47si547brfabg)

#### Avoid looping wherever possible

```ruby
[:thing1, :thing2].do |thing|
  describe "#{thing}" do
    let(:object) { FactoryGirl.create(thing) }
    it "can dance if it wants to" do
      object.dances?.should be_true
    end
  end
end
```

##### Problems with this loop:

- If there is a factory defined for :thing1 but not :thing2, the error we get (spec+line number) is not isolatable
- Stack traces are harder to read and decipher, and CI suite will end up re-running two tests instead of just the failing one

#### Tags for test focus

```ruby
describe SomeThing do
  context "a context which is working totally fine" do
    it "behaves very politely" do
      # ...
    end

    it "does not freak out" do
      # ...
    end
  end

  context "a context of interest to debugging", investigate: true do
    it "does a thing which is working but may fail after your changes" do
      # ... do the iffy thing
    end

    it "does the thing that broke the CI suite", focus: true do
      # ... do the bad thing
    end
  end
end
```

```
zeus rspec something_spec.rb --tag focus
```

> That will run just the one broken test. If you want to include the outer context, use:

```
zeus rspec something_spec.rb --tag investigate
```

> If you need to run all the other stuff, you can use an exclusion filter:

```
zeus rspec something_spec.rb --tag ~focus
```

> Just remember to remove these tags when no longer necessary. Tags can however be purposely leveraged to differentiate between specs that need to run on each build vs. longer-running tests, or to focus on specifically identified, critical smoke tests.

#### Use lets over @variables wherever possible

```ruby
describe ServicingFee do
  before(:each) { @servicing_fee = ServicingFee.new amount_owed: 50 }

  context "payments" do
    it "should update amount_owed and amount_paid appropriately" do
      @servicing_fee.apply_payment 30
      @servicing_fee.amount_paid.should == 30
      @servicing_fee.amount_owed.should == 20
      
      @servicing_fee.reverse_payment 20
      @servicing_fee.amount_owed.should == 40
      @servicing_fee.amount_paid.should == 10
    end
  end

  context "some other context that needs a ServicingFee" do
    it "should do other things" do
      @servicing_fee.do_other_things
      @servicing_fee.should be_something_else
    end
  end

  context "a context that doesn't need a ServicingFee" do
    it "should blow up when initialized incorrectly" do
      expect { ServicingFee.new 50 }.to raise_error
    end
  end
end
```

##### Problems with this...

1. @servicing_fee is created for all three contexts, including the third where it's not necessary
3. Setup code is contained in the example
2. Expectations are hard-coded and implicitly calculated from setup code
4. Main example is really testing two behaviours: #apply_payment and #reverse_payment

##### Moving @servicing_fee into a let fixes the first issue

```ruby
describe ServicingFee do
  let(:servicing_fee) { ServicingFee.new amount_owed: 50 }

  context "payments" do
    it "should update amount_owed and amount_paid appropriately" do
      servicing_fee.apply_payment 30
      servicing_fee.amount_paid.should == 30
      servicing_fee.amount_owed.should == 20
      
      servicing_fee.reverse_payment 20
      servicing_fee.amount_owed.should == 40
      servicing_fee.amount_paid.should == 10
    end
  end

  context "some other context that needs a ServicingFee" do
    it "should do other things" do
      servicing_fee.do_other_things
      servicing_fee.should be_something_else
    end
  end

  context "a context that doesn't need a ServicingFee" do
    it "should blow up when initialized incorrectly" do
      expect { ServicingFee.new 50 }.to raise_error
    end
  end
end
```

##### Setup code and expectations can be moved into lets and befores (when necessary):

> Move the ServicingFee into a let, as well as its initialization option. Define the test case setup options as lets as well. Now the expectations can be defined in terms of these variables, and they can be selectively overridden in deeper contexts as necessary.

```ruby
describe ServicingFee do
  let(:servicing_fee)   { ServicingFee.new amount_owed: initially_owed }
  let(:initially_owed)  { 50 }
  let(:payment_amount)  { 30 }
  let(:reversal_amount) { 20 }

  context "payments" do
    before(:each) { servicing_fee.apply_payment payment_amount }
    it "should update amount_owed and amount_paid appropriately" do
      servicing_fee.amount_paid.should == payment_amount
      servicing_fee.amount_owed.should == initially_owed - payment_amount
      
      servicing_fee.reverse_payment reversal_amount
      servicing_fee.amount_owed.should == initially_owed - payment_amount + reversal_amount
      servicing_fee.amount_paid.should == payment_amount - reversal_amount
    end
  end
end
```

##### Examples that do too much can be split out into contexts with embedding (preserving ordering):

> The first before block applies to all examples in the context. The second context is embedded and has its own before block, which will be run *after* the outer before block. Befores and afters are run from the outside in, whereas let resolution works from the inside out.

```ruby
describe ServicingFee do
  let(:servicing_fee)   { ServicingFee.new amount_owed: initially_owed }
  let(:initially_owed)  { 50 }
  let(:payment_amount)  { 30 }
  let(:reversal_amount) { 20 }

  context "when applying a payment," do
    before(:each) { servicing_fee.apply_payment payment_amount }
    it "updates amount_owed and amount_paid appropriately" do
      servicing_fee.amount_paid.should == payment_amount
      servicing_fee.amount_owed.should == initially_owed - payment_amount
    end

    context "and subsequently reversing a part of it," do
      before(:each) { servicing_fee.reverse_payment reversal_amount }
      it "increases amount_owed and decreases amount_paid by the reversal amount" do
        servicing_fee.amount_owed.should == initially_owed - payment_amount + reversal_amount
        servicing_fee.amount_paid.should == payment_amount - reversal_amount
      end
    end
  end
end
```

> Beginning contexts with words like "with" or "when" or "and", and including a trailing comma is useful for identifying failing tests:

```
ServicingFee (describe)
  when applying a payment, (context)
    updates amount_owed and amount_paid appropriately (example description, "it" string)
      and subsequently reversing a part of it, (context)
        increases amount_owed and decreases amount_paid by the reversal amount (example description)
```

> These are all run together like this:

```
ServicingFee when applying a payment, and subsequently reversing a part of it, increases amount_owed and decreases amount_paid by the reversal amount
```

> It's good to name contexts with an eye to how they would read in a one-line spec failure report.


##### Refactoring using embedded contexts and selective let redefinitions

(partner_referrals_before_spec.rb)


```ruby
context "partner referrals" do
  it "should not pay a referral bonus to the referring partner for first loan if referring partner's bank account is blank" do
    @new_partner = FactoryGirl.create(:partner)
    @referring_partner = FactoryGirl.create(:partner, :no_bank_account)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referring_partner, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should be_empty
  end

  it "should not pay a referral bonus to the referring partner for first loan if referring partner's bank account fields are blank" do
    @new_partner = FactoryGirl.create(:partner)
    @referring_partner = FactoryGirl.create(:partner)
    @bank_account = @referring_partner.bank_account
    @bank_account.transit_number = ""
    @bank_account.institution_number = ""
    @bank_account.account_number = ""
    @bank_account.save(validate: false)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referring_partner, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should be_empty
  end

  it "should pay a referral bonus to the referring partner for first loan only" do
    @new_partner = FactoryGirl.create(:partner)
    @referring_partner = FactoryGirl.create(:partner)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referring_partner, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should have(1).entry
    sub_transfer.first.amount.to_f.round(2).should == 100
    sub_transfer.first.foreign_bank_account.should == @referring_partner.bank_account
    sub_transfer.first.service_agreement_bank_account.should == @loan.lender.operating_service_agreement_bank_account
    sub_transfer.first.foreign_transaction_type.should == 'credit'
    
    @loan2 = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @loan2.disburse!
    sub_transfer2 = get_transfer_by_category_from_loan(@loan2, 'partner_referral_bonus')
    sub_transfer2.should be_empty      
  end

  it "should pay a referral bonus to the referring broker for first loan only" do
    @new_partner = FactoryGirl.create(:partner)
    @referring_broker_employee = FactoryGirl.create(:broker_employee)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referring_broker_employee, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should have(1).entry
    sub_transfer.first.amount.to_f.round(2).should == 100
    sub_transfer.first.foreign_bank_account.should == @referring_broker_employee.partner_group.bank_account
    sub_transfer.first.service_agreement_bank_account.should == @loan.lender.operating_service_agreement_bank_account
    sub_transfer.first.foreign_transaction_type.should == 'credit'

    @loan2 = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @loan2.disburse!
    sub_transfer2 = get_transfer_by_category_from_loan(@loan2, 'partner_referral_bonus')
    sub_transfer2.should be_empty
  end

  it "should pay a referral bonus to the referring distributor for first loan only" do
    @new_partner = FactoryGirl.create(:partner)
    @referring_distributor_employee = FactoryGirl.create(:distributor_employee)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referring_distributor_employee, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should have(1).entry
    sub_transfer.first.amount.to_f.round(2).should == 100
    sub_transfer.first.foreign_bank_account.should == @referring_distributor_employee.partner_group.bank_account
    sub_transfer.first.service_agreement_bank_account.should == @loan.lender.operating_service_agreement_bank_account
    sub_transfer.first.foreign_transaction_type.should == 'credit'

    @loan2 = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @loan2.disburse!
    sub_transfer2 = get_transfer_by_category_from_loan(@loan2, 'partner_referral_bonus')
    sub_transfer2.should be_empty
  end

  it "should pay a referral bonus to the referrer for first loan only" do
    @new_partner = FactoryGirl.create(:partner)
    @referrer_employee = FactoryGirl.create(:referrer_employee)
    @loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @partner_referral = FactoryGirl.create(:partner_referral, referrer: @referrer_employee, new_partner_id: @new_partner.id)
    @new_partner.reload
    @loan.disburse!

    sub_transfer = get_transfer_by_category_from_loan(@loan, 'partner_referral_bonus')
    sub_transfer.should have(1).entry
    sub_transfer.first.amount.to_f.round(2).should == 100
    sub_transfer.first.foreign_bank_account.should == @referrer_employee.partner_group.bank_account
    sub_transfer.first.service_agreement_bank_account.should == @loan.lender.operating_service_agreement_bank_account
    sub_transfer.first.foreign_transaction_type.should == 'credit'

    @loan2 = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: @new_partner)
    @loan2.disburse!
    sub_transfer2 = get_transfer_by_category_from_loan(@loan2, 'partner_referral_bonus')
    sub_transfer2.should be_empty
  end

  it "should pay an extra bonus for the twentieth referred partner by a partner" do
    partner = FactoryGirl.create(:partner) 
    referring_partner = FactoryGirl.create(:partner)
    partner_referral  = FactoryGirl.create(:partner_referral, referrer: referring_partner, new_partner_id: partner.id)
    loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: partner)
    PartnerReferral.any_instance.stubs(:total_num_referrals).returns(19)
    loan.disburse!
    loan.reload
    partner_referral.reload
    partner_referral.paid_date.should be_present
    get_transfer_by_category_from_loan(loan, 'partner_referral_bonus').first.amount.to_f.round(2).should == 600
  end

  it "should pay an extra bonus for the twentieth referred partner by any broker employee of a broker" do
    partner = FactoryGirl.create(:partner) 
    referring_broker_employee = FactoryGirl.create(:broker_employee)
    partner_referral  = FactoryGirl.create(:partner_referral, referrer: referring_broker_employee, new_partner_id: partner.id)
    loan = FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: partner)
    PartnerReferral.any_instance.stubs(:total_num_referrals).returns(19)
    loan.disburse!
    loan.reload
    partner_referral.reload
    partner_referral.paid_date.should be_present
    get_transfer_by_category_from_loan(loan, 'partner_referral_bonus').first.amount.to_f.round(2).should == 600
  end
end
```

##### Problems with this...

1. No setup code at all; setup is repeated per example.
1. Not DRY at all. Examples have nearly identical structure, although subtle differences prevent obvious refactoring.
1. Hard-coded expectations on the referral rewards and related amounts.

> First thing to note is that the actors in these examples are the same: a new partner, a partner that makes the referral, a loan (or two), and a referral model. The differences occur in the type of the referring partner, which is sometimes reflected in the variable name (e.g. @referring_partner, @referring_broker_employee, @referring_distributor_employee). The setup code can easily be moved to a before block, or into a group of lets, if we can mimic the variation in referring partner using embedded contexts. Finally, the expectation amounts should be defined in a let at the top, for easy modification should they change in the future.

#### Step 1 Refactor

```ruby
context "partner referrals", focus: true do
  let(:new_partner)               { FactoryGirl.create(:partner) }
  let(:referrer)                  { FactoryGirl.create(:partner) }
  let(:partner_referral)          { FactoryGirl.create(:partner_referral, referrer: referrer, new_partner_id: new_partner.id) }
  let(:loan)                      { FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: new_partner) }

  let(:referral_reward_amount)          { 250 } # loan.paid_referral_reward_amount }
  let(:extra_referral_bonus)            { 500 }
  let(:num_referrals_for_extra_bonus)   { 10 }

  context "when the referrer is a partner with a blank bank account" do
    let(:referrer) { FactoryGirl.create(:partner, :no_bank_account) }

    it "should not pay a referral bonus to the referrer for the first loan" do
      new_partner
      referrer
      loan
      partner_referral
      new_partner.reload
      loan.disburse!

      sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
      sub_transfer.should be_empty
    end
  end

  context "when the referrer is a partner with bank account fields that are blank" do
    let(:bank_account) { referrer.bank_account }
    before(:each) do 
      bank_account.transit_number     = ""
      bank_account.institution_number = ""
      bank_account.account_number     = ""
      bank_account.save(validate: false)
    end

    it "should not pay a referral bonus to the referrer for the first loan" do
      new_partner
      referrer
      loan
      partner_referral
      new_partner.reload
      loan.disburse!

      sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
      sub_transfer.should be_empty
    end
  end

  context "when the referrer has a second loan that is also disbursed" do
    let(:loan2) { FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: new_partner) }

    context "when the referrer is a partner" do
      it "should pay a referral bonus to the referrer for the first loan only" do
        new_partner
        referrer
        loan
        partner_referral
        new_partner.reload
        loan.disburse!

        sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
        sub_transfer.should have(1).entry
        sub_transfer.first.amount.to_f.round(2).should == referral_reward_amount
        sub_transfer.first.foreign_bank_account.should == referrer.bank_account
        sub_transfer.first.service_agreement_bank_account.should == loan.lender.operating_service_agreement_bank_account
        sub_transfer.first.foreign_transaction_type.should == 'credit'

        loan2.disburse!
        sub_transfer2 = get_transfer_by_category_from_loan(loan2, 'partner_referral_bonus')
        sub_transfer2.should be_empty      
      end
    end

    context "when the referrer is a broker employee" do
      let(:referrer) { FactoryGirl.create(:broker_employee) }

      it "should pay a referral bonus to the referrer for the first loan only" do
        new_partner
        referrer
        loan
        partner_referral
        new_partner.reload
        loan.disburse!

        sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
        sub_transfer.should have(1).entry
        sub_transfer.first.amount.to_f.round(2).should == referral_reward_amount
        sub_transfer.first.foreign_bank_account.should == referrer.partner_group.bank_account
        sub_transfer.first.service_agreement_bank_account.should == loan.lender.operating_service_agreement_bank_account
        sub_transfer.first.foreign_transaction_type.should == 'credit'

        loan2.disburse!
        sub_transfer2 = get_transfer_by_category_from_loan(loan2, 'partner_referral_bonus')
        sub_transfer2.should be_empty
      end
    end

    context "when the referrer is a distributor employee" do
      let(:referrer) { FactoryGirl.create(:distributor_employee) } 

      it "should pay a referral bonus to the referrer for the first loan only" do
        new_partner
        referrer
        loan
        partner_referral
        new_partner.reload
        loan.disburse!

        sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
        sub_transfer.should have(1).entry
        sub_transfer.first.amount.to_f.round(2).should == referral_reward_amount
        sub_transfer.first.foreign_bank_account.should == referrer.partner_group.bank_account
        sub_transfer.first.service_agreement_bank_account.should == loan.lender.operating_service_agreement_bank_account
        sub_transfer.first.foreign_transaction_type.should == 'credit'

        loan2.disburse!
        sub_transfer2 = get_transfer_by_category_from_loan(loan2, 'partner_referral_bonus')
        sub_transfer2.should be_empty
      end
    end

    context "when the referrer is a referrer employee" do
      let(:referrer) { FactoryGirl.create(:referrer_employee) }

      it "should pay a referral bonus to the referrer for the first loan only" do
        new_partner
        referrer
        loan
        partner_referral
        new_partner.reload
        loan.disburse!

        sub_transfer = get_transfer_by_category_from_loan(loan, 'partner_referral_bonus')
        sub_transfer.should have(1).entry
        sub_transfer.first.amount.to_f.round(2).should == referral_reward_amount
        sub_transfer.first.foreign_bank_account.should == referrer.partner_group.bank_account
        sub_transfer.first.service_agreement_bank_account.should == loan.lender.operating_service_agreement_bank_account
        sub_transfer.first.foreign_transaction_type.should == 'credit'

        loan2.disburse!
        sub_transfer2 = get_transfer_by_category_from_loan(loan2, 'partner_referral_bonus')
        sub_transfer2.should be_empty
      end
    end
  end

  context "when the referrer refers ten partners" do
    context "when the referrer is a partner" do
      let(:referrer) { FactoryGirl.create(:partner) }

      it "should pay an extra bonus for the twentieth referred partner" do
        new_partner
        referrer
        partner_referral

        loan
        PartnerReferral.any_instance.stubs(:total_num_referrals).returns(num_referrals_for_extra_bonus - 1)
        loan.disburse!
        loan.reload
        partner_referral.reload
        partner_referral.paid_date.should be_present
        get_transfer_by_category_from_loan(loan, 'partner_referral_bonus').first.amount.to_f.round(2).should == referral_reward_amount + extra_referral_bonus
      end
    end

    context "when the referrer is a broker employee" do
      let(:referrer) { FactoryGirl.create(:broker_employee) }

      it "should pay an extra bonus for the twentieth referred partner" do
        new_partner
        referrer
        partner_referral

        loan
        PartnerReferral.any_instance.stubs(:total_num_referrals).returns(num_referrals_for_extra_bonus - 1)
        loan.disburse!
        loan.reload
        partner_referral.reload
        partner_referral.paid_date.should be_present
        get_transfer_by_category_from_loan(loan, 'partner_referral_bonus').first.amount.to_f.round(2).should == referral_reward_amount + extra_referral_bonus
      end
    end
  end
end
```

##### Items covered in Step 1 refactoring:

- [x] Extract factory creation component of setup
- [ ] Extract remainder of test case setup
- [x] Move primary expectation parameters into a let and change references in examples
- [x] Use general definitions with contextual overrides to prepare for DRYing out the rest of setup and test expectations

> Remaining setup tasks can still be extracted. References forcing factory creation in a specific order can be removed where the ordering is not necessary. Test expectations can be moved into a helper method, and finally that helper method can be made accessible through a _should_-style matcher.


#### Step 2 Refactor

```ruby
context "partner referrals" do
  RSpec::Matchers.define :reward_referral_correctly_given do |partner_referral, referral_reward_amount|
    match do |actual|
      referral_transfer = actual
      verify_referral_transfer_for(referral_transfer, partner_referral, referral_reward_amount)
    end
  end

  let(:referral_reward_amount)          { 250 } # PartnerReferral::REFERRAL_BONUS
  let(:extra_referral_bonus)            { 500 } # PartnerReferral::EXTRA_REFERRAL_BONUS
  let(:num_referrals_for_extra_bonus)   { 10 }  # PartnerReferral::NUM_REFERRALS_FOR_EXTRA_BONUS

  let(:new_partner)       { FactoryGirl.create(:partner) }
  let(:referrer)          { FactoryGirl.create(:partner) }
  let(:partner_referral)  { FactoryGirl.create(:partner_referral, referrer: referrer, new_partner_id: new_partner.id) }
  let(:loan)              { FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: new_partner) }

  let(:sub_transfer)      { get_transfer_by_category_from_loan(loan,  'partner_referral_bonus') }
  let(:sub_transfer2)     { get_transfer_by_category_from_loan(loan2, 'partner_referral_bonus') }

  let(:pre_test_setup)    { nil } # Override in deeper contexts if stubbing etc. needs to occur before main test setup
  let(:test_setup)        { pre_test_setup; partner_referral; loan.disburse! }

  before(:each)           { test_setup }

  context "when the referrer is a partner with a blank bank account" do
    let(:referrer) { FactoryGirl.create(:partner, :no_bank_account) }

    it "should not pay a referral bonus to the referrer for the first loan" do
      sub_transfer.should be_empty
    end
  end

  context "when the referrer is a partner with bank account fields that are blank" do
    let(:bank_account) { referrer.bank_account }
    let(:pre_test_setup) do
      # This test requires that the bank_account info be blanked out before the actual loan disbursal takes place:
      bank_account.transit_number     = ""
      bank_account.institution_number = ""
      bank_account.account_number     = ""
      bank_account.save(validate: false)
    end

    it "should not pay a referral bonus to the referrer for the first loan" do
      sub_transfer.should be_empty
    end
  end

  context "when the referrer has a second loan that is also disbursed" do
    let(:loan2) { FactoryGirl.create(:partner_loan, :ing, :ready_for_disbursement, partner: new_partner) }

    context "when the referrer is a partner" do
      it "should pay a referral bonus to the referrer for the first loan only" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount)

        loan2.disburse!
        sub_transfer2.should be_empty      
      end
    end

    context "when the referrer is a broker employee" do
      let(:referrer) { FactoryGirl.create(:broker_employee) }

      it "should pay a referral bonus to the referrer for the first loan only" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount)

        loan2.disburse!
        sub_transfer2.should be_empty
      end
    end

    context "when the referrer is a distributor employee" do
      let(:referrer) { FactoryGirl.create(:distributor_employee) }

      it "should pay a referral bonus to the referrer for the first loan only" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount)

        loan2.disburse!
        sub_transfer2.should be_empty
      end
    end

    context "when the referrer is a referrer employee" do
      let(:referrer) { FactoryGirl.create(:referrer_employee) }

      it "should pay a referral bonus to the referrer for the first loan only" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount)

        loan2.disburse!
        sub_transfer2.should be_empty
      end
    end
  end

  context "when the referrer refers ten partners" do
    let(:pre_test_setup)  { PartnerReferral.any_instance.stubs(:total_num_referrals).returns(num_referrals_for_extra_bonus - 1) }

    context "when the referrer is a partner" do
      let(:referrer) { FactoryGirl.create(:partner) }

      it "should pay an extra bonus for the tenth referred partner" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount + extra_referral_bonus)
      end
    end

    context "when the referrer is a broker employee" do
      let(:referrer) { FactoryGirl.create(:broker_employee) }

      it "should pay an extra bonus for the tenth referred partner" do
        sub_transfer.should reward_referral_correctly_given(partner_referral, referral_reward_amount + extra_referral_bonus)
      end
    end
  end
end
```

```ruby
module LoanSpecHelpers
  # ... lots of other stuff omitted
  
  def verify_referral_transfer_for(transfer, partner_referral, referral_reward_amount)
    referrer              = partner_referral.referrer
    referrer_bank_account = referrer.bank_account ? referrer.bank_account : referrer.partner_group.bank_account

    partner_referral.reload.paid_date.should be_present
    transfer.should have(1).entry
    transfer.first.amount.to_f.round(2).should == referral_reward_amount
    transfer.first.foreign_bank_account.should == referrer_bank_account
    transfer.first.service_agreement_bank_account.should == loan.lender.operating_service_agreement_bank_account
    transfer.first.foreign_transaction_type.should == 'credit'
  end
end
```

##### Items covered in Step 2 refactoring:

- [x] Extract remainder of test case setup, eliminate unnecessary forcing of factory creation order
- [x] Move all the expectations into a helper method
- [x] Create a custom RSpec matcher built on the helper method

#### Shared examples with a parameter

```ruby
describe PaymentFile do
  describe "#parser" do
    it "returns the correct parser" do
      subject.parser.is_a? RegionServices::report_parser
    end
  end

  describe ".regional_delegate" do
    it "returns the appropriate regional delegate" do
      subject.class.regional_delegate.should eq RegionServices::payment_file_delegate
    end
  end

  describe ".remote_dir" do
    include_examples "a class method delegation", :remote_dir
  end

  describe ".remote_host" do
    include_examples "a class method delegation", :remote_host
  end

  describe ".remote_host_user" do
    include_examples "a class method delegation", :remote_host_user
  end
end
```

> This removes a lot of boilerplate. With proper naming of the shared example this is more readable and efficient when many methods are being delegated to a regional_delegate for the model. This is achieved with the following shared example definition:


```ruby
shared_examples_for "a class method delegation" do |message|
  let(:call_class_method)  { subject.class.send(message) }
  specify "subject delegates #{message} to subject.class.regional_delegate" do
    subject.class.regional_delegate.expects(message)
    call_class_method
  end
end
```

#### Implicit subject, parameterized shared example groups

```ruby
RSpec::Matchers.define :validate_payment_file do
  match do |parser|
    parser.valid_payment_file?
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
```

#### Ordering of befores and afters

> C indicates the block comes from a config block inside spec_helper.
> S indicates the block comes from within the spec file itself.

```
C before suite
  Spec file begins evaluation
S before ALL
C before each
S before each
  example 1 code
S after each
C after each
  example 1 passes
C before each
S before each
  example 2 code
S after each
C after each
  example 2 passes
C before each
S before each
  example 3 code
S after each
C after each
  example 3 passes
S after ALL
C after suite
```

#### Examples and example groups should only be defined in spec files

```ruby
describe SomeSpecFile do
  context "permissions" do
    perform_loan_permissions_tests [
      {:method => :get, :action => :show, :declined_response_success => true},
      {:method => :get, :action => :edit, :declined_response_success => false},
      {:method => :post, :action => :update, :declined_response_success => false},
      {:method => :get, :action => :state_change_reason, :declined_response_success => true},
      {:method => :post, :action => :update_borrower, :declined_response_success => false, :params => {borrower: {}, data: {}}},
      {:method => :post, :action => :bank_details, :declined_response_success => false},
      {:method => :get, :action => :new_coborrower, :declined_response_success => false},
      {:method => :post, :action => :create_coborrower, :declined_response_success => false, :params => {coborrower: {}, data: {}}},
      {:method => :post, :action => :set_no_coborrower, :declined_response_success => false},
      {:method => :get, :action => :coborrower_hold_for_bureau, :declined_response_success => false},
      {:method => :get, :action => :coborrower_credit_bureau_timeout, :declined_response_success => false}
    ]
  end
end

#### spec_helper.rb:

def perform_loan_permissions_tests(permission_test_hashes, options = {})
  let(:partner_loan) { FactoryGirl.create :partner_loan, options.merge(:partner => partner)}
  let(:stranger_loan) { FactoryGirl.create :partner_loan}
  let(:declined_partner_loan) { FactoryGirl.create :partner_loan, :declined, options.merge(:partner => partner)}
  permission_test_hashes.each do |permission_test_hash|
    context "##{permission_test_hash[:action]}" do
      it "succeeds for partner" do
        send(permission_test_hash[:method], permission_test_hash[:action], {id: partner_loan.id}.merge(permission_test_hash[:params] || {}))
        response.response_code.should_not == 401
      end

      it "fails for stranger" do
        send(permission_test_hash[:method], permission_test_hash[:action], {id: stranger_loan.id}.merge(permission_test_hash[:params] || {}))
        response.response_code.should == 401
      end

      it "reacts correctly for declined loan" do
        send(permission_test_hash[:method], permission_test_hash[:action], {id: declined_partner_loan.id}.merge(permission_test_hash[:params] || {}))
        if permission_test_hash[:declined_response_success]
          response.response_code.should_not == 401
        else
          response.response_code.should == 401
        end
      end
    end
  end
end
```

> The problem here is if any of these tests fail, rspec will return the location of the example, which is the filepath and line number where an expectation was not met. This cannot be used to manually or automatically (in the CI suite) re-run the test, because the file contains no outer describe/context block to place the failing example in context for the RSpec runner.

