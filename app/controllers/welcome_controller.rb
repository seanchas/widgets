class WelcomeController < ApplicationController

  def index
  end
  
  def widget
  end
  
  def examples
    render :layout => "examples"
  end
  
  def security
    render :layout => "security"
  end
  
  def security_docs
    render :layout => "docs"
  end
  
end
