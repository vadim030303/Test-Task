require 'json'
require 'watir'
require 'nokogiri'
require 'pry'
require_relative 'helpers'
require_relative 'account'
 
class BendigoBank
  include Helpers
  attr_reader :browser, :accounts
 
  def initialize
    @browser = Watir::Browser.new :chrome
  end
 
  def execute
    goto_bank_page
    validate_of_site_availability
    parse_accounts
    parse_transactions
  end
 
  def goto_bank_page
    puts "Visiting: https://demo.bendigobank.com.au/banking/sign_in"
    browser.goto('https://demo.bendigobank.com.au/banking/sign_in')
    browser.window.maximize
 
    wait_for_presence(browser.button(value: "personal"))
    browser.button(value: "personal").click
  end
 
  def account_ids
    wait_for_presence(browser.div(data_semantic: "accounts-list"))
    account_ids = browser.lis(data_semantic: "account-item").map do |li|
      li.attributes[:data_semantic_account_id]
    end
  end
 
  def parse_accounts
    @accounts = []
    account_ids[0..3].map do |acc_id|
      browser.li(data_semantic_account_id: /#{acc_id}/).click
 
      account_info = Nokogiri::HTML.parse(browser.div(data_semantic: "account", data_semantic_account_id: /#{acc_id}/).html)
 
      accounts << parse_account(account_info, acc_id)
 
      browser.back
    end
  end
 
  def transaction_ids
    wait_for_presence(browser.div(data_semantic: "activity-tab-content"))
 
    transaction_ids = browser.lis(data_semantic: "activity-item").map do |li|
      li.attributes[:data_semantic_activity_score]
    end
    transaction_ids = transaction_ids.uniq
  end
 
  def parse_transactions
    accounts.each do |account|
      browser.li(data_semantic_account_id: /#{account.id}/).click
 
      wait_for_presence(browser.div(data_semantic: "accounts-show"))
      select_2_month_transactions

      wait_for_presence(browser.div(data_semantic: "activity-feed", data_semantic_activity_feed_is_loading: "false"))
      browser_message = browser.div(class: "full-page-message__content")

      if browser_message.present? && browser_message.text.match?(/No matching activity found./)
        account.transactions = []
        next 
      end

      wait_for_presence(browser.button(data_semantic: "detailed-account-view"))
      browser.button(data_semantic: "detailed-account-view").click
 
      wait_for_presence(browser.div(data_semantic: "activity-tab-content"))
      account_name = browser.li(data_semantic_account_id: /#{account.id}/).text
 
      acc_transactions = transaction_ids.map do |tr_id|
        wait_for_presence(browser.div(data_semantic: "activity-tab-content"))
        browser.li(data_semantic_activity_score: /#{tr_id}/).click
 
        wait_for_presence(browser.button(data_semantic: "print-receipt"))
 
        transaction_info = Nokogiri::HTML.parse(browser.div(data_semantic: "transactions-show").html)
        browser.back
 
        parse_transaction_info(transaction_info,account_name)
      end
      account.transactions = acc_transactions
    end
 
    accounts_info = { accounts: parsed_accounts }
    puts JSON.pretty_generate(accounts_info)
  end
 
  def select_2_month_transactions
    wait_for_presence(browser.link(data_semantic: "filter"))
    browser.link(data_semantic: "filter").click
 
    wait_for_presence(browser.link(data_semantic: "date-filter"))
    browser.link(data_semantic: "date-filter").click
 
    wait_for_presence(browser.span(text: "Custom Date Range"))
    browser.span(text: "Custom Date Range").click
 
    wait_for_presence(browser.input(data_semantic: "filter-from-date-input"))
    date_2_month_ago = Date.today.prev_month(2).strftime("%d/%m/%Y")
    browser.text_field(data_semantic: "filter-from-date-input").set(date_2_month_ago)
 
    wait_for_presence(browser.input(data_semantic: "filter-to-date-input"))
    browser.input(data_semantic: "filter-to-date-input").click
    browser.div(text: "Select Today").click
 
    wait_for_presence(browser.button(data_semantic: "apply-filter-button"))
    browser.button(data_semantic: "apply-filter-button").click
 
    wait_for_presence(browser.button(data_semantic: "apply-filters-button"))
    browser.button(data_semantic: "apply-filters-button").click
  end
 
  private
 
  def parse_account(account_info, acc_id)
    balance_text = account_info.css("[data-semantic='header-current-balance']").text
    balance = parse_curreny_and_balance(balance_text).last
    currency = parse_curreny_and_balance(balance_text).first
 
    Account.new(
      name: account_info.css("[data-semantic='account-name']").text,
      currency: currency,
      balance: balance,
      nature: "account",
      id: acc_id
    )
  end
 
  def parse_transaction_info(transaction_info,account_name)
    transaction = {}
    amount_text = transaction_info.css("[data-semantic='payment-summary']").text
    amount =  parse_transaction_amount(transaction_info)
 
    date_text = transaction_info.css("[data-semantic='sent-on']").text
    date = parse_transaction_date(date_text)
 
    description = parse_transaction_description(transaction_info)
    currency_text = transaction_info.css("[data-semantic='payment-amount']").text
    currency = parse_transaction_currency(currency_text)
    account_name = parse_account_name(account_name)
 
    transaction.merge!(
      date: date,
      description: description,
      amount: amount,
      currency: currency,
      account_name: account_name
    )
  end
 
  def parse_curreny_and_balance(balance)
    currency = balance[/^./].match?(/$/) ? "USD" : "-"
    current_balance_text = balance[/([0-9]+[.|,]*)+/].gsub(",", "")
    current_balance = balance.match?(/-|−/) ? -1 * current_balance_text.to_f : 1 * current_balance_text.to_f
 
    [currency, current_balance]
  end
 
  def parse_account_name(name)
    account_name = browser.divs(class: ["_34WIxjCkBw", "_5KR4Am_fPD"]).map(&:text)
  end
 
  def parse_transaction_currency(currency)
    currency = currency[/^./].match?(/$/) ? "USD" : "-"
  end
 
  def parse_transaction_amount(transaction_info)
    amount_text = transaction_info.css("[data-semantic='payment-summary']").text
    amount = amount_text[/([0-9]+[.|,]*)+/]
 
    paid_label = transaction_info.css("div.stamp--paid--payment")
 
    paid_label.one? ? -1 * amount.to_f : amount.to_f
  end
 
  def parse_transaction_description(transaction_info)
    if transaction_info.css("h2[data-semantic='transaction-title']").one?
      transaction_info.css("h2[data-semantic='transaction-title']").text
    elsif transaction_info.css("h2[data-semantic='payee-name']").one?
      transaction_info.css("h2[data-semantic='payee-name']").text
    else
      transaction_info.css('header.panel__header').text
    end
  end
 
  def parse_transaction_date(date)
    data_text = DateTime.parse(date).strftime("%Y-%m-%d")
  end
 
  def parse_account_name(account_name)
    account_name_text = account_name.split(' ').take(3).join(" ")
  end
 
  def parsed_accounts
    accounts.map do |account|
      {
        name: account.name,
        currency: account.currency,
        balance: account.balance,
        nature: account.nature,
        transactions: account.transactions
      }
    end
  end
 
  def validate_of_site_availability
    return unless browser.text.match?(/None of your accounts are visible./)
    raise StandardError, "Site is not available, please try again."
  end
end