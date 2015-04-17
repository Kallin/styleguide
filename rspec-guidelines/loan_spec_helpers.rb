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