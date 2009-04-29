class Admin::GatewayConfigurationsController < Admin::BaseController
  resource_controller
  
  before_filter :load_data
    
  update.response do |wants|
    wants.html {redirect_to edit_object_url}
  end
    
  private
  
      def load_data
        @available_gateways = Gateway.find(:all, :order => :name)
      end  
end
