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

  desc "Start hydra stack using cloud formation template and scripts in s3."
  task :form_cloud do
    base_name  = "#{ENV['USER']||ENV['USERNAME']}.hydra-scripts"
    template = AWS::S3.new.buckets["#{base_name}.cloudform"].objects["hydra-vpc.json"]

    puts "Forming stack from: #{template}"
    cfm = AWS::CloudFormation.new
    stack = cfm.stacks.create('hydra', template, :capabilities => ["CAPABILITY_IAM"] )

    sleep 5
    puts "Cost estimate: #{stack.estimate_template_cost}"

    for i in 1..10 do
      sleep 30
      puts "Status:  #{stack.status}"
      puts "Message: #{stack.status_reason}" 
      if stack.status == "CREATE_COMPLETE" then break end
    end
  end

  desc "Validate local template"
  task :temple_test do
    cfm = AWS::CloudFormation.new
    hsh = cfm.validate_template(File.read("scripts/aws/cloudform/hydra-vpc.json"))

    hsh.each_pair{|k,v| puts "#{k}: #{v}"}
  end
 


end
