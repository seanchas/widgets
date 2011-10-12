class WelcomeController < ApplicationController

  def index
    render :layout => 'index'
  end
  
  def widget
    render :layout => false
  end

end
