# James - 2008-09-12

# Rake tasks to repair Kete data to ensure integrity

namespace :kete do
  namespace :repair do
    
    # Run all tasks
    task :all => ['kete:repair:fix_topic_versions', 'kete:repair:set_missing_contributors']
    
    desc "Fix invalid topic versions (adds version column value or prunes on a case-by-case basis."
    task :fix_topic_versions => :environment do
      
      # This task repairs all Topic::Versions where #version is nil. This is a problem because it causes
      # exceptions when visiting history pages on items.
      
      pruned, fixed = 0, 0
      
      # First, find all the candidate versions
      Topic::Version.find(:all, :conditions => ['version IS NULL'], :order => 'id ASC').each do |topic_version|
        
        topic = topic_version.topic
        
        # Skip any problem topics
        next unless topic.version > 0
        
        # Find all existing versions
        existing_versions = topic.versions.map { |v| v.version }.compact
        
        # Find the maximum version
        max = [topic.version, existing_versions.max].compact.max
        
        # Find any versions that are missing from the range of versions we expect to find,
        # given the maximum version we found above..  
        missing = (1..max).detect { |v| !existing_versions.member?(v) }
        
        if missing
          
          # The current topic_version has no version attribute, and there is a version missing from the set.
          # Therefore, the current version is likely the missing one.
          
          # Set the version on this topic_version to the missing one..
          
          topic_version.update_attributes!(
            :version => missing,
            :version_comment => topic_version.version_comment.to_s + " NOTE: Version number fixed automatically."
          )
          
          print "Fixed missing version for Topic with id = #{topic_version.topic_id} (version #{missing}).\n"
          fixed = fixed + 1
          
        elsif topic.versions.size > max
          
          # There are more versions than we expected, and there are no missing version records.
          # So, this version must be additional to requirements. We need to remove the current topic_version.
          
          # Clean up any flags/tags
          topic_version.flags.clear
          topic_version.tags.clear

          # Check the associations have been cleared
          topic_version.reload

          raise "Could not clear associations" if \
            topic_version.flags.size > 0 || topic_version.tags.size > 0

          # Prune if we're still here..
          topic_version.destroy

          print "Deleted invalid version for Topic with id = #{topic_version.topic_id}.\n"
          pruned = pruned + 1
                      
        end
            
      end
      
      print "Finished. Removed #{pruned} invalid topic versions.\n"
      print "Finished. Fixed #{fixed} topic versions with missing version attributes.\n"
    end
    
    desc "Set missing contributors on topic versions."
    task :set_missing_contributors => :environment do
      fixed = 0
      
      # This rake task runs through all topic_versions and adds a contributor/creator to any
      # which are missing them.
      
      # This is done because a missing contributor results in exceptions being raised on the
      # topic history pages.
      
      Topic::Version.find(:all).each do |topic_version|
        
        # Check that this is a valid topic version.
        next if topic_version.version.nil?
        
        # Identify any existing contributors for the current topic_version and skip to the next
        # if existing contributors are present.
        
        sql = <<-SQL
          SELECT COUNT(*) FROM contributions 
            WHERE contributed_item_type = "Topic" 
            AND contributed_item_id = #{topic_version.topic.id} 
            AND version = #{topic_version.version};
        SQL
        
        next unless Contribution.count_by_sql(sql) == 0
        
        # Add the admin user as the contributor and add a note to the version comment.
        
        Contribution.create(
          :contributed_item => topic_version.topic,
          :version => topic_version.version,
          :contributor_role => topic_version.version == 1 ? "creator" : "contributor",
          :user_id => 1
        )
        
        topic_version.update_attribute(:version_comment, topic_version.version_comment.to_s + " NOTE: Contributor added automatically. Actual contributor unknown.")
        
        print "Added contributor for version #{topic_version.version} of Topic with id = #{topic_version.topic.id}.\n"
        fixed = fixed + 1
      end
      
      print "Finished. Added contributor to #{fixed} topic versions.\n"
    end
    
    desc "Copies incorrectly located uploads to the correct location"
    task :correct_upload_locations => :environment do
      
      # Display a warning to the user, since we're copying files around on the file system
      # and there is a possibility of overwriting something important.
      
      puts "\n/!\\ IMPORTANT /!\\\n\n"
      puts "This task will copy files from audio_recordings/ into audio/, and videos/ into video/, "
      puts "where they should be stored.\n\n"

      puts "You should only run this once, to avoid overwriting files.\n\n"

      puts "Please ensure you have backed up your application directory before continuing. If you "
      puts "have not done this, press Ctrl+C now to abort. Otherwise, press any key to continue.\n\n"

      puts "Press any key to continue, or Ctrl+C to abort.."
      STDIN.gets
      puts "Running.. please wait.."
      
      # A list of folders to copy files between
      
      copy_directives = {
        'audio_recordings' => 'audio',
        'videos' => 'video'
      }
      
      # Do this in the context of both public and private files
      
      ['public', 'private'].each do |privacy_folder|
        copy_directives.each_pair do |src, dest|
          from  = File.join(RAILS_ROOT, privacy_folder, src, ".")
          to    = File.join(RAILS_ROOT, privacy_folder, dest)
          
          # Skip if the wrongly named folder doesn't exist
          next unless File.exists?(from)
          
          # Make the destination folder if it does not exist
          # Also detects symlinks, so should be Capistrano safe.
          FileUtils.mkdir(to) unless File.exists?(to)
          
          # Copy and report what's going on
          print "Copying #{from.gsub(RAILS_ROOT, "")} to #{to.gsub(RAILS_ROOT, "")}.."
          FileUtils.cp_r(from, to)
          print " Done.\n"
        end
      end
      
      Rake::Task['kete:repair:check_uploaded_files'].invoke
    end
    
    desc "Check uploaded files for accessibility"
    task :check_uploaded_files => :environment do

      puts "Checking files.. please wait.\n\n"
      
      inaccessible_files = [AudioRecording, Document, ImageFile, Video].collect do |item_type|
        item_type.find(:all).collect do |instance|
          instance unless File.exists?(instance.full_filename)
        end
      end.flatten.compact
      
      if inaccessible_files.empty?
        puts "All files could be found. No further action required."
      else
        puts "WARNING: Some files could not be found. See below for details:\n\n"
        inaccessible_files.each do |instance|
          puts "- Missing uploaded file for #{instance.class.name} with ID #{instance.id.to_s}."
        end
        puts "\nRun rake kete:repair:correct_upload_locations to relocate files to the correct "
        puts "location.\n\n"
        
        puts "If you have used Capistrano to deploy your Kete instance, you may also need to copy"
        puts "archived files from previous versions of your Kete application, which are saved "
        puts "under 'releases' in your main application folder."
        puts "See http://kete.net.nz/documentation/topics/show/207 for complete instructions."
      end
    end
    
  end
end
