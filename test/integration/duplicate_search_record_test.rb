require File.dirname(__FILE__) + '/integration_test_helper'

# James - 2008-12-17
# This test is specifically geared to test for duplicate search record regression that has occured.

class DuplicateSearchRecordTest < ActionController::IntegrationTest
  context "A Kete instance" do
    
    setup do
      
      # Clean the zebra instance because we rely heavily on checking in this in tests.
      bootstrap_zebra_with_initial_records
      
      add_sarah_as_super_user
      login_as('sarah')
      
      @new_basket = new_basket
      add_paul_as_member_to(@new_basket)
      User.find_by_login('paul').add_as_member_to_default_baskets
      
      login_as('sarah')
    end
    
    should "return no results because the zebra db is empty" do
      visit "/site/all/topics/"

      for name in ZOOM_CLASSES.map { |klass| zoom_class_plural_humanize(klass) }

        # Check that no records exist for each item type
        body_should_contain "#{name} (0)"

        # Check that no search results appear for each item type
        click_link "#{name} (0)"

        # Exception specifically for video
        name = "video" if name == "Videos"

        # Exception specifically for discussion
        name = "comments" if name == "Discussion"

        body_should_contain "Results in #{name.downcase}"
        body_should_contain "No results found."
 
      end
    end

    should "only show one search result for a new topic" do
      topic = new_topic :title => "This is a new topic"
      should_appear_once_in_search_results(topic)
    end

    should_eventually "only show one search result for a new item of any type"

    should "only show one search result for a new topic when a related topic is created" do
      create_a_topic_with_a_related_topic
    end

    should "only show one search result when a related topic is edited, then the original topic is edited" do
      create_a_topic_with_a_related_topic

      update_item(@related_topic, :title => "Related topic with title changed")
      [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }

      update_item(@topic, :title => "Original topic with title changed")
      [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }
    end
         
    should "only show one search result when a comment is added to a related topic" do
      [@@site_basket, @new_basket].each do |basket|
        turn_off_full_moderation(basket)
        
        create_a_topic_with_a_related_topic(basket)

        update_item(@related_topic, :title => "Related topic with title changed")
        [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }

        update_item(@topic, :title => "Original topic with title changed")
        [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }

        visit "/#{basket.urlified_name}/topics/show/#{@related_topic.id}"

        click_link "join this discussion"
        fill_in "comment_title", :with => "This is a new comment!"
        fill_in "comment_description", :with => "Obviously this is a test."
        click_button "Save"

        body_should_contain "There are 1 comments in this discussion."
        body_should_contain Comment.last.title
        body_should_contain Comment.last.description, :number_of_times => 1

        update_item(@topic, :title => "Original topic with title changed")
        [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }
      end
    end
    
    # James - 2008-12-21
    # Work in progress. The below test fails due to a mission contributor on a new version of an existing
    # item when full moderation is on for the basket.
    
    # should "only show one search result when a comment is added to a related topic with moderation" do
    #   # [@@site_basket, @new_basket].each do |basket|
    #   [@@site_basket].each do |basket|
    #     turn_on_full_moderation(basket)
    #     
    #     create_a_topic_with_a_related_topic(basket)
    #     
    #     # Right now this is failing to a moderation contribution email. See email from James 2008-12-18.
    #     login_as('paul')
    #     update_item(@related_topic, :title => "Related topic with title changed")
    #     should_appear_once_in_search_results(@related_topic, :title => @related_topic.title)
    #     
    #     login_as('sarah')
    #     @related_topic.reload
    #     moderate_restore(@related_topic, :version => 4)
    #     [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }
    #     
    #     login_as('paul')
    #     update_item(@topic, :title => "Original topic with title changed")
    #     should_appear_once_in_search_results(@topic, :title => @topic.title)
    #     
    #     login_as('sarah')
    #     moderate_restore(@topic)
    #     [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }
    #     
    #     visit "/#{basket.urlified_name}/topics/show/#{@related_topic.id}"
    #           
    #     click_link "join this discussion"
    #     fill_in "comment_title", :with => "This is a new comment!"
    #     fill_in "comment_description", :with => "Obviously this is a test."
    #     click_button "Save"
    #           
    #     body_should_contain "There are 1 comments in this discussion."
    #     body_should_contain Comment.last.title
    #     body_should_contain Comment.last.description, :number_of_times => 1
    #     
    #     login_as('paul')
    #     update_item(@topic, :title => "Original topic with title changed")
    #     # should_not_appear_in_search_results(@topic)
    #     
    #     login_as('sarah')
    #     moderate_restore(@topic)
    #     [@topic, @related_topic].each { |t| should_appear_once_in_search_results(t) }
    #   end
    # end
    
    teardown do
      ZOOM_CLASSES.each do |class_name|
        eval(class_name).destroy_all
      end
    end
    
  end
  
  private
  
    def create_a_topic_with_a_related_topic(basket = @@site_basket)
      
      login_as('paul') if is_fully_moderated?(basket)
      
      @topic = new_topic({ :title => "A topic" }, basket)
      
      # Ensure that the topic has been moderated correctly.
      assert_equal(BLANK_TITLE, @topic.title, "Basket fully_moderated setting: " + basket.settings[:full_moderated].inspect) if is_fully_moderated?(basket)
      
      should_not_appear_in_search_results(@topic) if is_fully_moderated?(basket)
      
      if is_fully_moderated?(basket)
        login_as('sarah')
        moderate_restore(@topic, :version => 1)
      end
      
      @topic.reload
      should_appear_once_in_search_results(@topic)
      
      # Emulate clicking the "Create" link for related topics
      login_as('paul') if is_fully_moderated?(basket)
      
      @related_topic = new_item({ :new_path => "/#{basket.urlified_name}/topics/new?relate_to_topic=#{@topic.id}", :title => "A topic related to 'A topic'", :success_message => "Related topic was successfully created." }, basket)
      
      should_not_appear_in_search_results(@related_topic) if is_fully_moderated?(basket)
      
      if is_fully_moderated?(basket)
        login_as('sarah')
        
        moderate_restore(@related_topic, :version => 1)
        @related_topic.reload
        assert_equal @related_topic.versions.find_by_version(1).title, @related_topic.title
      end
      
      visit "/#{basket.urlified_name}/topics/show/#{@topic.id}/"
      
      body_should_contain "<a href=\"/#{basket.urlified_name}/topics/show/#{@related_topic.id}"
      should_appear_once_in_search_results(@topic)
      should_appear_once_in_search_results(@related_topic)
    end
  
    def is_fully_moderated?(basket)
      basket.settings[:fully_moderated].to_s == "true"
    end
    
end