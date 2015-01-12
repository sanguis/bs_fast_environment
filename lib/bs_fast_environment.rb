#!/usr/bin/env ruby
require 'rubygems'
require 'securerandom'
# require "beanstalkapp"
class Bs_Fast_Envronment

  def self.validate_options(options, operations)
  end

  def self.mk_file_system(options, app='drupal')
    FileUtils.mkdir_p "#{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]}/#{options["files"]}"
    FileUtils.chown options["app_owner"], options["app_owner"], "#{options["sites_parent_dir"]}/#{options["client"]}"
    FileUtils.chown_R options["app_owner"], options["app_owner"], "#{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]}"
    begin
      FileUtils.chown_R options["php_user"], options["app_owner"], "#{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]}/#{options["files"]}"
    rescue
      puts "Can not change 'files' directory owner to #{options["php_user"]}.\n Please enter sudoers password:"
      system("sudo chown -R #{options["php_user"]}:#{options["app_owner"]} #{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]}/#{options["files"]}")
    end
    puts "File system prepared"
  end

  def self.mk_db(options)
    # making MySQL info
    require "sequel"
    random_password = SecureRandom.hex(20)
    new_db = "#{options["client"].gsub(/-/,'_')}_#{options["instance"]}"
    if options["mysql_password"] == nil
      print "What is the mysql #{options["mysql_user"]}'s password? "
      sql_password = gets.chomp
    else
      sql_password = options["mysql_password"]
    end

    root_connect = Sequel.connect("mysql://#{options["mysql_user"]}:#{sql_password}@localhost")
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

  def self.mk_vhost(options, app = 'drupal')

    File.open("/etc/nginx/sites-enabled/#{options["client"]}_#{options["instance"]}", 'w+') do |f|
      f.puts vhost_drupal(options)
    end
    system "sudo service nginx reload"
  end

  def self.vhost_drupal(options)
    case options["instance"]
    when "dev"
      subdomain = "#{options["client"]}.#{options["instance"]}"
    when "stage"
      subdomain = "#{options["client"]}.#{options["instance"]}"
    else
      subdomain = "#{options["instance"]}-#{options["client"]}.dev"
    end
    full_domain = "#{subdomain}.knectar.com"

    # setting the php version;
    case options["php_version"]
    when "5.3"
      php_socket = "php-fpm"
    when "5.4"
      php_socket = "php54-fpm"
    when "5.5"
      php_socket = "php55-fpm"
    else 
      puts "The value #{options["php_version"]} is invalid. Please enter 5.3, 5.4 or 5.5 other options will fail."
      exit
    end
    puts "Creating the vhost file for http://#{full_domain}. It will run on the php socket #{php_socket}."
    return "server {
#the URL
  server_name #{subdomain}.knectar.com;
#path to the local host
  root #{options["sites_parent_dir"]}/#{options["client"]}/#{options["instance"]};
#include the app template
  set $private_dir #{options["private_files"]};
  set $php_socket #{php_socket};
  include /etc/nginx/apps/password.conf;
  include /etc/nginx/apps/drupal;
}"
  end
  
  # fork or detect existing branch by the name of options["instance"] from default branch
  # deploy code in to newly created file system
  def self.bs_deploy_code(options) 
   
    bs= Hash.new
    options['beanstalkapp'].each do |k|
      k.to_hash.each_pair do |key,value|
        bs["#{key}"] = value
      end
    end
    p bs
    Beanstalk::API::Base.Setup(
      :domain   => bs['domain'],
      :login    => bs['login'],
      :password => bs['password']
    )
puts    Beanstalk::API::Account.find
  end
end
