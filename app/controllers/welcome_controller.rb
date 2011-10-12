class WelcomeController < ApplicationController

  def index
    render :layout => 'index'
  end
  
  def widget
    @filters = ISS.filters(params[:engine], params[:market])[:small] #rescue nil
    @columns = ISS.columns(params[:engine], params[:market]) #rescue nil
    Rails.logger.debug @filters.inspect
    render :layout => false
  end

end
