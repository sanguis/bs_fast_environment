require 'rest_client'
require 'json'
#require "bs_rest_api_helper/version"

class BsRestApiHelper
  def initialize(domain, login, password, project_name)
    url = "https://#{login}:#{password}@#{domain}.beanstalkapp.com/api/"
    @url = url
    project_data = JSON.parse(RestClient.get "#{url}repositories/#{project_name}.json")
    @project_data = project_data['repository']
    @project_url = "#{@url}#{@project_data['id']}/"
  end
 # basic connection test
  def connect
    return  @project_data
  end
  def get_server_environment(environment_name)
    envs =  JSON.parse(RestClient.get "#{@project_url}server_environments.json")
    env = envs.find {|server| server["server_environment"]["name"] == environment_name }
    unless env.nil?
      return env['server_environment'];
    else
      return nil
    end
  end

  #create environment if missing
  def create_server_environment(environment_name, automatic = TRUE, color = "label-blue")
    unless self.get_server_environment(environment_name).nil?
      return nil
    else
        new_env = RestClient.post(
          "#{@project_url}server_environments.json",
          {
            'server_environment' => {
              'name' => environment_name,
              'branch_name' => environment_name,
              'automatic' => automatic,
              'color_label' => color
            }
          },
          {
            'Content-Type' => 'application/json'
          }
        )
        new_env = JSON.parse(new_env)
        return new_env['server_environment']
    end
  end

  #checks to see if a server exists
  #retursn nil if environment or server is not  found.
  #returns a hash {server =>, 'environment =>
  def get_server(server_name, environment_name)
    env = get_server_environment(environment_name)
    unless env.nil?
      servers = JSON.parse(RestClient.get "#{@project_url}release_servers.json?environment_id=#{env['id']}")
      rel_server = servers.find {|i| i["release_server"]["name"] == server_name }
      if rel_server.nil?
        return {'server' => nil, 'environment' => env }
      else
        return {'server' => rel_server['release_server'], 'environment' => env }
      end
    else
        return {'server' => nil, 'environment' => nil }
    end
  end

  def server_environment_release(comment, environment_name, revision = nil)
    env = get_server_environment(environment_name)
    unless env.nil?
      if revision.nil?
        payload = {
          'release' => {
            'comment'  => comment,
            'deploy_from_scratch' => false,
          }
        }
      else
        payload = {
          'release' => {
            'comment'  => comment,
            'revision' => revision
          }
        }
      end
      new_env = RestClient.post(
        "#{@project_url}releases.json?environment_id=#{env['id']}",
        payload,
        {
          'Content-Type' => 'application/json'
        }
      )
      new_env = JSON.parse(new_env)
      return new_env['release']
    else
      return nil
    end
  end

  #returns a created server
  def create_server(server_name, environment_name, login, remote_addr, remote_path, shell_code = "")
    server = get_server(server_name, environment_name)
    if server['environment'].nil?
      server['environment'] = create_server_environment(environment_name)
    end
    if server['server'].nil?
      new_env = RestClient.post(
        "#{@project_url}release_servers.json?environment_id=#{server['environment']['id']}",
        {
          "release_server" => {
            "name" => server_name,
            "remote_path" => remote_path,
            "authenticate_by_key" => true,
            "login" => login,
            "port" => 22,
            "protocol" => "sftp",
            "local_path" => "/",
            "remote_addr" => remote_addr,
            "shell_code" => shell_code
          },
        },
        {
          'Content-Type' => 'application/json'
        }
      )
        new_env = JSON.parse(new_env)
        return {'status' => 'created', 'release_server' => new_env['release_server']}

    else
        return {'status' => 'exists', 'release_server' => server['server']}
    end
  end
  def find_branches()
    return JSON.parse(RestClient.get "#{@url}repositories/#{@project_data['id']}/branches.json")
  end
  def has_branch(find_branch)
    branch =  find_branches().find {|i|i['branch'] == find_branch}
    if branch.nil?
      return false
    else
      return true
    end
  end
end
