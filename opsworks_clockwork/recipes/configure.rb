# Adapted from rails::configure: https://github.com/aws/opsworks-cookbooks/blob/master/rails/recipes/configure.rb

include_recipe "deploy"
include_recipe "opsworks_clockwork::service"

node[:deploy].each do |application, deploy|
  execute "restart-clockwork-service-#{application}" do
    command "sudo monit restart -g clockwork_#{application}_group"
  end

  node.default[:deploy][application][:database][:adapter] = OpsWorks::RailsConfiguration.determine_database_adapter(application, node[:deploy][application], "#{node[:deploy][application][:deploy_to]}/current", force: node[:force_database_adapter_detection])
  deploy = node[:deploy][application]

  template "#{deploy[:deploy_to]}/shared/config/database.yml" do
    source "database.yml.erb"
    cookbook 'rails'
    mode "0660"
    group deploy[:group]
    owner deploy[:user]
    variables(
      database: deploy[:database],
      environment: deploy[:rails_env]
    )

    notifies :run, "execute[restart-clockwork-service-#{application}]"

    only_if do
      deploy[:database][:host].present? && File.directory?("#{deploy[:deploy_to]}/shared/config/")
    end
  end

  template "#{deploy[:deploy_to]}/shared/config/memcached.yml" do
    source "memcached.yml.erb"
    cookbook 'rails'
    mode "0660"
    group deploy[:group]
    owner deploy[:user]
    variables(
      memcached: deploy[:memcached] || {},
      environment: deploy[:rails_env]
    )

    notifies :run, "execute[restart-rails-app-#{application}]"

    only_if do
      deploy[:memcached][:host].present? && File.directory?("#{deploy[:deploy_to]}/shared/config/")
    end
  end
end
