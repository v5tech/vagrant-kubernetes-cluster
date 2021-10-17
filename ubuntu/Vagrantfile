# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  config.vm.provision "shell", path: "bootstrap.sh"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  
  # Kubernetes Master Server
  config.vm.define "kmaster" do |node|
  
    node.vm.box               = "generic/ubuntu2004"
    node.vm.box_check_update  = false
    node.vm.box_version       = "3.3.0"
    node.vm.hostname          = "kmaster.k8s.com"

    node.vm.network "private_network", ip: "192.168.56.100"
  
    node.vm.provider :virtualbox do |v|
      v.name    = "kmaster"
      v.memory  = 2048
      v.cpus    =  2
    end
  
    node.vm.provision "shell", path: "bootstrap_kmaster.sh"
  
  end


  # Kubernetes Worker Nodes
  NodeCount = 2

  (1..NodeCount).each do |i|

    config.vm.define "kworker#{i}" do |node|

      node.vm.box               = "generic/ubuntu2004"
      node.vm.box_check_update  = false
      node.vm.box_version       = "3.3.0"
      node.vm.hostname          = "kworker#{i}.k8s.com"

      node.vm.network "private_network", ip: "192.168.56.10#{i}"

      node.vm.provider :virtualbox do |v|
        v.name    = "kworker#{i}"
        v.memory  = 2048
        v.cpus    = 2
      end

      node.vm.provision "shell", path: "bootstrap_kworker.sh"

    end

  end

end
