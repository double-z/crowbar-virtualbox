#VBoxManage list vms
#"ubuntu__8063" {2bbef874-c459-4ece-afcb-a85ac6d674a4}
#"ubuntu__4475" {84a1d4b5-9848-4c28-8cf2-99110315ce99}
#"ubuntu__3289" {2a9c7e3b-fa4c-47bc-867d-4bdaad02e67f}

vm_names = lambda { |vm| vm.match(/"(.*)".*\{(.*)\}/)[1]} 
running_vms = %x{VBoxManage list runningvms}.map(&vm_names)
all_vms = %x{VBoxManage list vms}.map(&vm_names)


running_vms.each do |vm|
  puts "stopping #{vm}" 
  %x[VBoxManage controlvm #{vm} poweroff]  
  puts "stopped #{vm}"	
end

all_vms.each do |vm|
  puts "deleting #{vm}" 
  %x[VBoxManage unregistervm #{vm} --delete]
  puts "deleted #{vm}"   
end



