require 'spec_helper'
require_relative '../bendigobank'

RSpec.describe BendigoBank do
  let!(:bendigobank) { described_class.new }
  let!(:accounts) { bendigobank.accounts = [] }

  describe "#parsed_accounts" do
    it "validates correct structure for first account" do
      accounts_html = Nokogiri::HTML(File.read("spec/fixtures/accounts.html"))
      parsed_account_instance = bendigobank.send(:parse_account, accounts_html, "12345")

      accounts << parsed_account_instance
      parsed_accounts = bendigobank.send(:parsed_accounts)

      expect(parsed_accounts.first).to eq(
        {
          balance: 2109.90,
          currency: "USD",
          name: "Demo Everyday Account",
          nature: "account",
          transactions: []
        }
      )
    end
  end

  describe "#parse_transaction_info" do
    it "validates correct transaction structure" do
      transactions_html = Nokogiri::HTML(File.read("spec/fixtures/transaction.html"))
      parsed_transaction = bendigobank.send(:parse_transaction_info, transactions_html, "Demo Everyday Account")

      expect(parsed_transaction).to eq(
        {
          date: "2020-08-17",
          description: "PaidFrom: Demo Everyday Account. toTo: Demo My Mastercard.$10.00$10.00",
          amount: 10.0,
          currency: "USD",
          account_name: "Demo Everyday Account"
        }
      )
    end

    it "parses transaction with negative amount" do
      transactions_negative_amount_html = Nokogiri::HTML(File.read("spec/fixtures/transaction_negative_amount.html"))
      parsed_transaction = bendigobank.send(:parse_transaction_info, transactions_negative_amount_html, "Demo Everyday Account")

      expect(parsed_transaction).to eq(
       {
          date: "2020-08-14",
          description: "paidTJTimothy Jones$12.00",
          amount: -12.0,
          currency: "USD",
          account_name: "Demo Everyday Account"
       }
      )
    end

    it "parses transaction with specific description selector" do
      transaction_description = Nokogiri::HTML(File.read("spec/fixtures/transaction_specific_description.html"))
      parsed_transaction = bendigobank.send(:parse_transaction_info, transaction_description, "Demo Everyday Account")

      expect(parsed_transaction).to eq(
       {
          date: "2020-07-22",
          description: "Kmart.",
          amount: 15.95,
          currency: "USD",
          account_name: "Demo Everyday Account"
       }
      )
    end
  end
end