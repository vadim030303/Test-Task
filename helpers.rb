module Helpers
  def wait_for_presence(value)
    Watir::Wait.until { value.present? }	
  end 
end