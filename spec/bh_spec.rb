require 'bs_rest_api_helper'
#//test data
project_name = 'whitetest'
environment_name = 'bar'

test_connect = BsRestApiHelper.new(auth[:domain], auth[:login], auth[:password], project_name)
test_server = "whitetest.dev.knectar.com"


RSpec.describe BsRestApiHelper  do
  context "basic intialzation" do
    it "tests basic api connection" do
      connect = BsRestApiHelper.new(auth[:domain], auth[:login], auth[:password], project_name)
      expect(connect.connect["name"]).to eq "#{project_name}"
    end
  end

  #server_environment CRUD
  context "get enviroment info" do
    it "tests envirment look up and pass" do
      expect(test_connect.get_server_environment(environment_name)['color_label']).to eq "yellow" 
    end 
  end
  context "get enviroment info" do
    it "tests envirment look up, but cant be found" do
      expect(test_connect.get_server_environment('dev')).to be_nil
    end 
  end
  context "if a server_environment is missing create it" do
    it "create missing server environment_name" do
      expect(test_connect.create_server_environment('dev', TRUE, 'label-blue')['color_label']).to eq "blue" 
    end
  end
  context "if a server_environment is found abort" do
    it "create missing server environment_name" do
      expect(test_connect.create_server_environment('dev', TRUE, 'label-blue')).to be_nil
    end
  end
  # server  crud functions
  context "if a server is missing create it" do
    it "create missing server _name" do
      expect(test_connect.create_server(test_server, 'dev')['name']).to eq test_server
    end
  end
  context "if a server is found abort" do
    it "create missing server _name" do
      expect(test_connect.create_server(test_server)).to be_nil
    end
  end
end
