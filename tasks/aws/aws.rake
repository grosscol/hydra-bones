

namespace :aws do

  desc "Push scripts to s3 buckets and make public read only."
  task :push_scripts do
    puts "Pushshing scripts to bucket: #{ENV['USER']||ENV['USERNAME']}-hydra-scripts"
  end

end
