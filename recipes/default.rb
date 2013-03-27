#
# Cookbook Name:: commons-ariadne
#
include_recipe "ariadne::default"

project = "commons"

bash "Installing Commons..." do
  action :nothing
  user "vagrant"
  group "vagrant"
  code <<-EOH
    drush -v -y si \
    --root=/mnt/www/html/#{project} \
    --db-url=mysql://root:root@localhost/#{project} \
    --site-name="QASite" \
    --account-name="admin" \
    --account-pass=commons \
    --account-mail=admin@example.com \
    --site-mail=site@example.com \
    commons commons_anonymous_welcome_text_form.commons_anonymous_welcome_title="Oh hai" \
    commons_anonymous_welcome_text_form.commons_anonymous_welcome_body="No shirts, no shoes, no service."\
    commons_create_first_group.commons_first_group_title="Internet People" \
    commons_create_first_group.commons_first_group_body="This is the first group on the page."
  EOH
end

bash "Building Commons..." do
  user "vagrant"
  group "vagrant"
  cwd "/mnt/www/html"
  code <<-EOH
    git clone --branch 7.x-3.x http://git.drupal.org/project/commons.git #{project}
    cd #{project} && drush make -y build-commons-dev.make
  EOH
  notifies :run, "bash[Installing Commons...]", :immediately
  not_if "test -d /mnt/www/html/#{project}"
end

site = node['ariadne']['host_name'].nil? ? "#{node['ariadne']['project']}.dev" : node['ariadne']['host_name']

web_app site do
  cookbook "ariadne"
  template "drupal-site.conf.erb"
  port node['apache']['listen_ports'].to_a[0]
  server_name site
  server_aliases [ "www.#{site}" ]
  docroot "/mnt/www/html/#{project}"
  enable_cgi node.run_list.expand(node.chef_environment, 'disk').recipes.include?("apache2::mod_fcgid")
  notifies :reload, "service[apache2]"
end

# Since Varnish isn't guaranteed to exist, need a helper function to restart service.
::Chef::Recipe.send(:include, Ariadne::Helpers)
restart_service "varnish"
