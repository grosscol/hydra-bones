require 'aws-sdk'

namespace :aws do

  desc "Push scripts to s3 buckets and make public read only."
  task :push_scripts do
    s3 = AWS::S3.new
    base_name = "#{ENV['USER']||ENV['USERNAME']}.hydra-scripts"

    # For each dir in scripts/aws, create bucket and upload scripts.
    dirs = Dir.glob('scripts/aws/*/')
    dirs.each do |d|
      bucket_name = "#{base_name}.#{File.basename(d)}"
      bucket = s3.buckets[bucket_name]
      bucket = s3.buckets.create(bucket_name,{:acl => :public_read}) unless bucket.exists?
      puts "Pushshing scripts to bucket: #{bucket_name}"

      Dir.entries(d).each do |f|
        fpath = File.join(d,f)
        if f[0] == '.' || !File.file?( fpath )
          next
        end
        puts "  pushing: #{fpath}" 
        bucket.objects[File.basename(fpath)].write(:file => fpath, :acl => :public_read)
      end
    end


  end

end
