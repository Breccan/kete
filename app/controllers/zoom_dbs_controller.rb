class ZoomDbsController < ApplicationController
  # everything else is handled by application.rb
  before_filter :login_required, :only => [:list, :index]

  permit "site_admin or admin of :current_basket"

  active_scaffold :zoom_db do |config|
    list.columns.exclude [:updated_at, :created_at, :zoom_password]
  end
end
