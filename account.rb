class Account
  attr_accessor :name, :currency, :balance, :nature, :transactions, :id

  def initialize(params)
    @name = params[:name]
    @currency = params[:currency]
    @balance = params[:balance]
    @nature = params[:nature]
    @id = params[:id]
    @transactions = []
  end
end