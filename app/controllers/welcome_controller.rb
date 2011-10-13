class WelcomeController < ApplicationController

  def index
    respond_to do |format|
      format.html { render :layout => 'index' }
      format.jsonp
    end
    
  end
  
  def widget
    filter  = params[:filter] || :small
    only    = params[:only].try(:split, ',') || %w(filters columns records)
    
    @filters = ISS.filters(params[:engine], params[:market])[filter] rescue nil           if only.include?('filters')
    @columns = ISS.columns(params[:engine], params[:market]) rescue nil                   if only.include?('columns')
    @records = ISS.records(params[:engine], params[:market], params[:params]) rescue nil  if only.include?('records')

    respond_to do |format|
      format.html { render :layout => false }
      format.jsonp
    end
  end

end
