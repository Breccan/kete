class ImagesController < ApplicationController
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def index
    redirect_to_search_for('StillImage')
  end

  def list
    index
  end

  def show
    @still_image = @current_basket.still_images.find(params[:id])
    @title = @still_image.title
    @creator = @still_image.creators.first
    @last_contributor = @still_image.contributors.last || @creator
    @view_size = params[:view_size] || "medium"
    @image_file = ImageFile.find_by_thumbnail_and_still_image_id(@view_size, @still_image)
    respond_to do |format|
      format.html
      format.xml { render :action => 'oai_record.rxml', :layout => false, :content_type => 'text/xml' }
    end
  end

  def new
    @still_image = StillImage.new
  end

  def create
    @still_image = StillImage.new(params[:still_image])
    @successful = @still_image.save

    if @successful
      # add this to the user's empire of creations
      # TODO: allow current_user whom is at least moderator to pick another user
      # as creator
      @still_image.creators << current_user

      @original_file = ImageFile.new(params[:image_file])
      @original_file.still_image_id = @still_image.id
      @original_file.save
      # attachment_fu doesn't insert our still_image_id into the thumbnails
      # automagically
      @original_file.thumbnails.each do |thumb|
        thumb.still_image_id = @still_image.id
        thumb.save!
      end
    end

    setup_related_topic_and_zoom_and_redirect(@still_image)
  end

  def edit
    @still_image = StillImage.find(params[:id])
  end

  def update
    @still_image = StillImage.find(params[:id])

    if @still_image.update_attributes(params[:still_image])
      # add this to the user's empire of contributions
      # TODO: allow current_user whom is at least moderator to pick another user
      # as contributor
      # uses virtual attr as hack to pass version to << method
      @current_user = current_user
      @current_user.version = @still_image.version
      @still_image.contributors << @current_user

      if !params[:image_file][:uploaded_file].blank?
        # if they have uploaded something new, insert it
        @original_file = ImageFile.update_attributes(params[:image_file])
      end

      prepare_and_save_to_zoom(@still_image)

      flash[:notice] = 'Image was successfully updated.'
      redirect_to :action => 'show', :id => @still_image
    else
      render :action => 'edit'
    end
  end

  def destroy
    zoom_destroy_and_redirect('StillImage','Image')
  end
end
