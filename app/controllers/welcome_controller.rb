class WelcomeController < ApplicationController

  def index
    render :layout => 'index'
  end
  
  def widget
    @engine = params[:engine]
    @market = params[:market]
    @params = params[:params]
  end

end
