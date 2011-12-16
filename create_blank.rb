require 'rubygems'
require 'virtualbox'
require 'fileutils'   

# monkey patch from https://github.com/hh/virtualbox/blob/da76afa639e11fcd9f0ab4a816876fb5bd30d579/lib/virtualbox/hard_drive.rb  

# needs some serious cleanup

module VirtualBox
  class VM 
    
    class << self

       # Creates and registers a new VM, and returns a
       # new VM object.
       #
       # @return [VM]
       def create(name)
         settings = VirtualBox::Lib.lib.virtualbox.compose_machine_filename(name)
         imachine = VirtualBox::Lib.lib.virtualbox.create_machine(settings, name)
         VirtualBox::Lib.lib.virtualbox.register_machine(imachine)
         return VirtualBox::VM.new(imachine)
       end
    end
  end 
  
  class HardDrive
    def validate
      super

      medium_formats = Global.global.system_properties.medium_formats.collect { |mf| mf.id }
      validates_inclusion_of :format, :in => medium_formats, :message => "must be one of the following: #{medium_formats.join(', ')}."

      validates_presence_of :location

      max_vdi_size = Global.global.system_properties.info_vd_size
      validates_inclusion_of :logical_size, :in => (0..max_vdi_size), :message => "must be between 0 and #{max_vdi_size}."
    end
    
    def create_hard_disk_medium(outputfile, format = nil)
      # Get main VirtualBox object
      virtualbox = Lib.lib.virtualbox

      # Assign the default format if it isn't set yet
      format ||= virtualbox.system_properties.default_hard_disk_format

      # Expand path relative to the default hard disk folder. This allows
      # filenames to exist in the default folder while full paths will use
      # the paths specified.
      # outputfile = File.expand_path(outputfile, virtualbox.system_properties.default_hard_disk_folder)
      outputfile = File.expand_path(outputfile, virtualbox.system_properties.default_machine_folder)

      # If the outputfile path is in use by another Hard Drive, lets fail
      # now with a meaningful exception rather than simply return a nil
      raise Exceptions::MediumLocationInUseException.new(outputfile) if File.exist?(outputfile)

      # Create the new {COM::Interface::Medium} instance.
      new_medium = virtualbox.create_hard_disk(format, outputfile)

      # Raise an error if the creation of the {COM::Interface::Medium}
      # instance failed
      raise Exceptions::MediumCreationFailedException.new unless new_medium

      # Return the new {COM::Interface::Medium} instance.
      new_medium
    end
    
  end
end    

def createvbox(os=:ubuntu,x64=false)
  boxnum = rand.to_s[2..4+1].to_i
  if os == :ubuntu 
    if x64
      boxname="ubuntu64_#{boxnum}"
    else
      boxname="ubuntu__#{boxnum}" 
    end
  end

  vbox = VirtualBox::VM.create boxname
  #vbox.description="A Box to Remember"
  
  vbox.memory_size = 2048 #I want to run a few of these  
  vbox.os_type_id = "Ubuntu"
  vbox.vram_size = 12 #just enough for fullscreen + 2d accel
  vbox.accelerate_2d_video_enabled=false #needed?
  vbox.audio_adapter.enabled=false # not needed
  vbox.usb_controller.enabled=false # not needed... yet
  
  newhd=VirtualBox::HardDrive.new
  newhd.location=File.join(File.dirname(vbox.settings_file_path),vbox.name+'.vdi') #within the VM dir
  gigabyte=1000*1000*1024
  newhd.logical_size=40*gigabyte
  newhd.save     

  newhd1=VirtualBox::HardDrive.new
  newhd1.location=File.join(File.dirname(vbox.settings_file_path),vbox.name+'1.vdi') #within the VM dir
  newhd1.logical_size=40*gigabyte
  newhd1.save
  
  controller_name='Sata Controller'
  vbox.with_open_session do |session|
    machine = session.machine
    machine.bios_settings.pxe_debug_enabled=true
    machine.add_storage_controller controller_name, :sata
    machine.attach_device(controller_name, 0, 0, :hard_disk, newhd.interface)
    machine.attach_device(controller_name, 1, 0, :hard_disk, newhd1.interface)
  end

  # this will boot from nerk only if we can't boot from disk
  vbox.boot_order=[:hard_disk ,:network,:null,:null]
  

  #vbox.extra_data['VBoxInternal/Devices/VMMDev/0/Config/KeepCredentials']='1'

  # This works when wanting to test all virtually
  # nic = vbox.network_adapters[0]
  # nic.attachment_type = :nat
  # requires a real tftp server
  ##`VBoxManage modifyvm "#{vbox.name}" --nattftpserver1 192.168.2.7`
  # vbox.extra_data['VBoxInternal/Devices/pcnet/0/LUN#0/Config/TFTPPrefix']='/var/www/'
  # vbox.extra_data['VBoxInternal/Devices/pcnet/0/LUN#0/Config/BootFile']='pxelinux.0'  ##`VBoxManage modifyvm "#{vbox.name}" --nattftpfile1 pxelinux.0`
  # nic.enabled = true
  # nic.save

  # This is what we do when we want to test a real pxe implementation
  nic = vbox.network_adapters[0]
  nic.attachment_type = :host_only
  nic.host_only_interface = 'vboxnet0'
  nic.enabled = true
  nic.save   
  
  nic = vbox.network_adapters[1]
  nic.attachment_type = :host_only
  nic.host_only_interface = 'vboxnet1'
  nic.enabled = true
  nic.save   
  
  vbox.save  
  # --ioapic on for the centos pxe boot
  `VBoxManage modifyvm #{boxname} --vrdeport 5010-5020 --ioapic on` 
  
  
  vbox 
end    

box = createvbox   

puts "created new box #{box.name}"
puts "start it with VBoxHeadless -s #{box.name}"

# add the iso:




