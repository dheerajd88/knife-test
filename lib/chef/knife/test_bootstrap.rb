require 'chef/knife'

module MyTestBootstrap
	class TestBootstrap < Chef::Knife
		banner "knife test bootstrap (options)"

		option :server_ip,
		 :short => "-s VALUE",
		 :long => "--server-ip VALUE",
		 :description => "Server Ip Address to bootstrap",
         :proc => Proc.new { |si| Chef::Config[:knife][:server_ip] = si }
		option :ssh_user,
		 :short => "-x VALUE",
		 :long => "--ssh-user VALUE",
		 :description => "SSH User name to login to machine",
		 :proc => Proc.new { |su| Chef::Config[:knife][:ssh_user] = su }
		option :ssh_password,
		 :short => "-P VALUE",
		 :long => "--ssh-password VALUE",
		 :description => "SSH User Password to login to machine",
		 :proc => Proc.new { |sp| Chef::Config[:knife][:ssh_password] = sp }
		def run
			unless name_args.size == 1
				puts "Please provide server IP to bootstrap"
				show_usage
				exit 1
			end
        end
    end
end