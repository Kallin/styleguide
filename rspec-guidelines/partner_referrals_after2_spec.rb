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
