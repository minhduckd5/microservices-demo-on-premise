Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  vms = [
    { name: "controller", ip: "192.168.56.10" },
    { name: "worker1",    ip: "192.168.56.11" },
    { name: "worker2",    ip: "192.168.56.12" },
  ]

  vms.each_with_index do |vm_cfg, idx|
    config.vm.define vm_cfg[:name] do |node|
      node.vm.hostname = vm_cfg[:name]
      node.vm.network "private_network", ip: vm_cfg[:ip]

      node.vm.provider "virtualbox" do |vb|
        vb.name   = "microservices-#{vm_cfg[:name]}"
        vb.memory = 2048
        vb.cpus   = 2
      end

      # Only provision with Ansible from the last VM definition so all hosts exist
      if idx == vms.length - 1
        node.vm.provision "ansible" do |ansible|
          ansible.playbook   = "infra/ansible/playbook.yml"
          ansible.inventory_path = "infra/ansible/inventory.ini"
          ansible.limit      = "all"
          ansible.verbose    = "v"
        end
      end
    end
  end
end
