class WelcomeController < ApplicationController

  def index
  end
  
  def widget
    @engine = params[:engine]
    @market = params[:market]
    @params = params[:params]
  end

end
