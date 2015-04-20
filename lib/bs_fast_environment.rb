#!/usr/bin/env ruby
require 'rubygems'
require 'securerandom'

class Bs_Fast_Envronment
  def initialize(options)
    case options["instance"]
    when "dev"
      subdomain = "#{options["client"]}.#{options["instance"]}"
    when "stage"
      subdomain = "#{options["client"]}.#{options["instance"]}"
    else
      subdomain = "#{options["instance"]}-#{options["client"]}.dev"
    end
    @full_domain = "#{subdomain}.knectar.com"
    @options = options
    @site_path = "#{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]}"
    apps = hash_extract(options['apps'])
    @app_options = hash_extract(apps[options['app']])
  end

  def self.mk_file_system(app='drupal')
    FileUtils.mkdir_p "#{@site_path}/#{@options["files"]}"
    FileUtils.chown @options["app_owner"], @options["app_owner"], "#{@options["sites_parent_dir"]}/#{@options["client"]}"
    FileUtils.chown_R @options["app_owner"], @options["app_owner"], "#{@site_path}"
    begin
      FileUtils.chown_R @options["php_user"], @options["app_owner"], "#{@site_path}/#{@options["files"]}"
    rescue
      puts "Can not change 'files' directory owner to #{@options["php_user"]}.\n Please enter sudoers password:"
      system("sudo chown -R #{@options["php_user"]}:#{@options["app_owner"]} #{@site_path}/#{@options["files"]}")
    end
    puts "File system prepared"
  end

  def self.mk_db()
    # making MySQL info
    require "sequel"
    random_password = SecureRandom.hex(20)
    new_db = "#{@options["client"].gsub(/-/,'_')}_#{@options["instance"]}"
    if @options["mysql_password"] == nil
      print "What is the mysql #{@options["mysql_user"]}'s password? "
      sql_password = gets.chomp
    else
      sql_password = @options["mysql_password"]
    end

    root_connect = Sequel.connect("mysql://#{@options["mysql_user"]}:#{sql_password}@localhost")
    begin
      root_connect.use(new_db)
    rescue 
      root_connect.run("CREATE DATABASE #{new_db};")
      root_connect.run("GRANT USAGE ON #{new_db}.* TO #{new_db}@localhost IDENTIFIED BY '#{random_password}'")
      root_connect.run("GRANT ALL ON #{new_db}.* TO #{new_db}@localhost")
    end

    root_connect.disconnect
    # created = Mysql.real_connect('localhost', new_db, random_password, new_db)
    # created.close
    puts "created database: #{new_db}"
    puts "created user:     #{new_db}"
    puts "password:         #{random_password}"
    puts "value for --db-url: mysql://#{new_db}:#{random_password}@localhost/#{new_db}"
  end

  # fork or detect existing branch by the name of @options["instance"] from default branch
  # deploy code in to newly created file system
  def bs_deploy_code() 
    bs = hash_extract(@options['beanstalkapp'])
    rs = hash_extract(@options['remote_server'])
    require 'bs_rest_api_helper.rb'
    instance = BsRestApiHelper.new(bs['domain'], bs['login'], bs['password'], @options['client'])
      mk_server = instance.create_server(@full_domain, @options['instance'], rs['login'], rs['remote_addr'], @site_path, @app_options['shell_code'])
    unless mk_server.nil?
      puts "Making Server and Deployment role if needed"
      if instance.has_branch(@options['instance']) && instance.server_environment_release("Initial deployment to #{@full_domain}", @options['instance'])
        puts "Server Created and files are deploying"

        elseif instance.has_branch(@options['instance']).false? && instance.server_environment_release("Initial deployment to #{@full_domain}", @options['instance']).nil?
        ## todo get app to do its own fork.
        puts  "Server Created but branch did not deploy as it does not exist yet please create it."
      else
        puts "Something went horribly wrong. No Deployment server or files were released"
      end
    end
  end
  #creates vhost file,
  def self.mk_vhost(app = 'drupal')

    File.open("/etc/nginx/sites-enabled/#{@options["client"]}_#{@options["instance"]}", 'w+') do |f|
      f.puts vhost_drupal()
    end
    system "sudo service nginx reload"
  end


  def vhost_drupal()
    # setting the php version;
    case @options["php_version"]
    when "5.3"
      php_socket = "php-fpm"
    when "5.4"
      php_socket = "php54-fpm"
    when "5.5"
      php_socket = "php55-fpm"
    else 
      puts "The value #{@options["php_version"]} is invalid. Please enter 5.3, 5.4 or 5.5 other @options will fail."
      exit
    end
    puts "Creating the vhost file for http://#{@full_domain}. It will run on the php socket #{php_socket}."

    # private files
    private_files = if @options["private_files"].nil?
                      '""'
                    else
                      @options["private_files"]
                    end

    return "server {
  #the URL
    server_name #{@full_domain};
  #path to the local host
    root #{@site_path};
  #include the app template
    set $private_dir #{private_files};
    set $php_socket #{php_socket};
    include /etc/nginx/password.conf;
    include /etc/nginx/cert.conf;
    include /etc/nginx/apps/drupal;
  }"
  end

  # Extracts nested data within yaml generated @options hash
  def hash_extract(a)
    h = Hash.new
    a.each do |k|
      k.to_hash.each_pair do |key,value|
        h["#{key}"] = value
      end
    end
    return h
  end
end

