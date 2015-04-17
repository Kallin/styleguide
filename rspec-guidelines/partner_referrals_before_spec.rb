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
