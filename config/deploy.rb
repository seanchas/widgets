# config valid only for current version of Capistrano
lock '3.4.0'

set :application,   'widgets'

set :scm,           :git
set :repo_url,      'git@gitlab.web-tech.moex.com:webdev/ror.widgets.git'
set :branch,        :develop

set :deploy_to, -> { "/opt/moex/ror/appservers/#{fetch(:application)}" }
set :format,         :pretty
set :log_level,      :debug
set :keep_releases,  5

set :rvm_ruby_version, '2.2.1@widgets'
set :rvm_type,         :user

set :linked_dirs,  fetch(:linked_dirs,  []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/environments/production.rb', 'config/initializers/hosts_configuration.rb')

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }


# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end

namespace :deploy do

  task :restart do
    on roles(:web), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

end

after 'deploy', 'deploy:restart'