class WelcomeController < ApplicationController

  def index
  end
  
  def widget
  end

  def widget_docs
    render :layout => "docs"
  end

  def tiny_docs
    render :layout => "docs"
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

  def otc
  end

  def rms
  end

  def mmakers
  end

  def search
  end
  
end
