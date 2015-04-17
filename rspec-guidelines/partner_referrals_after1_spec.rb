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

      it "should pay an extra bonus for the tenth referred partner" do
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

      it "should pay an extra bonus for the tenth referred partner" do
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
