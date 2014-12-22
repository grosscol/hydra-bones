require 'aws-sdk'

namespace :aws do

  desc "Push scripts to s3 buckets and make public read only."
  task :push_scripts do
    bucket_name = "#{ENV['USER']||ENV['USERNAME']}-hydra-scripts"
    puts "Pushshing scripts to bucket: #{bucket_name}"

    s3 = AWS::S3.new

    # Get the existing bucket or create one if not extant.
    bucket = s3.buckets[bucket_name]
    bucket = s3.buckets.create(bucket_name,{:acl => :public_read}) unless bucket.exists?

    # Push all scripts in scripts/aws to s3
    Dir.glob('scripts/aws/*').each do |f|
      puts "pushing: #{f}" 
      bucket.objects[File.basename(f)].write(:file => f, :acl => :public_read)
    end


  end

end
