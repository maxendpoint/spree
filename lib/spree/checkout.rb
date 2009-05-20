# Custom logic to be included in OrdersController.  It has intentionally been isolated in its own library to make it 
# easier for developers to customize the checkout process.
module Spree::Checkout

  def checkout
    build_object 
    load_object 
    load_data
    load_checkout_steps                                             

    @order.transaction do
      @order.lock!
      @order.update_attributes(params[:order])

      # additional default values needed for checkout
      @order.bill_address ||= Address.new(:country => @default_country)
      @order.ship_address ||= Address.new(:country => @default_country) 
      if @order.creditcards.empty?
        @order.creditcards.build(:month => Date.today.month, :year => Date.today.year)
      end
      @shipping_method = ShippingMethod.find_by_id(params[:method_id]) if params[:method_id]  
      @shipping_method ||= @order.shipping_methods.first    
      @order.shipments.build(:address => @order.ship_address, :shipping_method => @shipping_method) if @order.shipments.empty?    

      if request.post?                           
        @order.creditcards.clear
        @order.attributes = params[:order]
        @order.creditcards[0].address = @order.bill_address if @order.creditcards.present?
        @order.user = current_user       
        @order.ip_address = request.env['REMOTE_ADDR']
        logger.warn("--- checkout, before update_totals: ship=%f, tax=%f, subtotal=%f, total=%f" % [@order.ship_amount, @order.tax_amount, @order.item_total, @order.total]) 
        @order.update_totals

        begin
          # need to check valid b/c we dump the creditcard info while saving
          if @order.valid?
            if params[:final_answer].blank?
              @order.save
            else                                           
              if @order.creditcards[0].nil?
                logger.warn("Checkout: Creditcard undefined at complete")
                flash.now[:error] = t("unable_to_authorize_credit_card") + ": Creditcard undefined error, try again."
                render :action => "checkout" and return 
              end
              unless Order.find_by_id(@order.id).allow_authorize?(@order.creditcards[0])
                logger.warn("Checkout: Duplicate checkout attempted on %s (%d)" % [@order.number, @order.id])
#                logger.warn("-- checkout: duplicate \nactive order:" + @order.to_yaml + "\ndatabase order:" + Order.find_by_id(@order.id).to_yaml)
                flash[:notice] = "Duplicate processing attempt, order already processed successfully!"
                redirect_to order_url(@order)
                return 
              end
#              logger.warn("--- checkout, before authorize: ship=%f, tax=%f, subtotal=%f, total=%f" % [@order.ship_amount, @order.tax_amount, @order.item_total, @order.total]) 
              @order.creditcards[0].authorize(@order.total)
#              logger.warn("--- checkout, after complete: ship=%f, tax=%f, subtotal=%f, total=%f" % [@order.ship_amount, @order.tax_amount, @order.item_total, @order.total]) 
              @order.complete
              # remove the order from the session
              session[:order_id] = nil 
            end
          else
            flash.now[:error] = t("unable_to_save_order")  
            render :action => "checkout" and return unless request.xhr?
          end       
        rescue Spree::GatewayError => ge
          flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
          render :action => "checkout" and return 
        end
        

        respond_to do |format|
          format.html do  
            flash[:notice] = t('order_processed_successfully')
            order_params = {:checkout_complete => true}
            order_params[:order_token] = @order.token unless @order.user
            redirect_to order_url(@order, order_params)
          end
          format.js {render :json => { :order_total => number_to_currency(@order.total), 
                                      :ship_amount => number_to_currency(@order.ship_amount), 
                                      :tax_amount => number_to_currency(@order.tax_amount),
                                      :ship_method => @order.shipment ? @order.shipment.shipping_method.name : nil,
                                      :available_methods => rate_hash}.to_json,
                            :layout => false}
        end
        
      end
    end
  end
  
  def load_checkout_steps
    @checkout_steps = %w{registration billing shipping shipping_method payment confirmation}
    @checkout_steps.delete "registration" if current_user
  end  
  
end
