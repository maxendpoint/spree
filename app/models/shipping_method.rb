class ShippingMethod < ActiveRecord::Base
  belongs_to :zone

  def calculate_shipping(shipment)
    logger.warn("Shipment and/or address is nil when attempting to calculate_shipping") and return 0 if shipment.nil? or shipment.address.nil?
    return 0 unless zone.include?(shipment.address)
    return shipping_calculator.constantize.new.send(:calculate_shipping, shipment)
  end   
  
  def available?(order)
    calculator = shipping_calculator.constantize.new                               
    return true unless calculator.respond_to?(:available?)
    calculator.available?(order)    
  end
end
