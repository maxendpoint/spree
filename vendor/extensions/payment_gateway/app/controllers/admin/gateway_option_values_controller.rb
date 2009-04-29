class Admin::GatewayOptionValuesController < Admin::BaseController
  resource_controller
  
  belongs_to :gateway_configuration

  index.before do
    chosen_gateway = Gateway.find(params[:gw_id])
    @option_values = @gateway_configuration.gateway_option_values
  end
  
  index.response do |wants|
    wants.html { render :partial => "options", 
                        :layout => false, 
                        :locals => {:option_values => @option_values} }
  end
    
end
