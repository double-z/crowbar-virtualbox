require 'virtualbox'
require 'fileutils'

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
  vbox.description="A Box to Remember"
  
  vbox.memory_size = 1024 #I want to run a few of these
  vbox.vram_size = 12 #just enough for fullscreen + 2d accel
  vbox.accelerate_2d_video_enabled=false #needed?
  vbox.audio_adapter.enabled=false # not needed
  vbox.usb_controller.enabled=false # not needed... yet
  
  newhd=VirtualBox::HardDrive.new
  newhd.location=File.join(File.dirname(vbox.settings_file_path),vbox.name+'.vdi') #within the VM dir
  gigabyte=1000*1000*1024
  newhd.logical_size=10*gigabyte
  newhd.save

  controller_name='Ye Olde IDE Controller'
  vbox.with_open_session do |session|
    machine = session.machine
    #possibly change the screen on each boot... for demo?
    #machine.bios_settings.logo_image_path='/var/www/ii.bmp' #256/8bit BMP
    machine.bios_settings.pxe_debug_enabled=true
    #machine.create_shared_folder 'Sharename', '/path', RW?, Automount?
    #machine.create_shared_folder 'HostRoot', '/', false, true
    #machine.create_shared_folder 'Unattended', '/var/unattended/install', false, true
    #machine.create_shared_folder 'Tmp', '/tmp', true, true
    machine.add_storage_controller controller_name, :ide
    machine.attach_device(controller_name, 0, 0, :hard_disk, newhd.interface)
    machine.attach_device(controller_name, 0, 1, :dvd, nil) 
  end

  vbox.storage_controllers[0].controller_type = :ich6 #or :piix4

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
  nic.attachment_type = :bridged
  nic.bridged_interface = 'eth0'
  nic.enabled = true
  nic.save
  
  # we should be able to ssh localhost -P <the 5 digits of after randomname>

  port = VirtualBox::NATForwardedPort.new
  port.name = 'ssh'
  port.guestport = 22
  port.hostport = boxnum
  port.protocol = :tcp
  vbox.network_adapters[0].nat_driver.forwarded_ports << port
  # Thank you Taylor for this:
  # "0800273B51A9".taylor_ruby_foo() # => "08-00-27-3B-51-A9" 
  tftp_conffile = "01-#{nic.mac_address.split(/(..)/).reject do|c| c.empty? end.join('-').downcase}"
  if os == :ubuntu and x64
    vbox.os_type_id="Ubuntu_64"
    File.symlink '/var/www/pxelinux.cfg/default-ubuntu64', "/var/www/pxelinux.cfg/#{tftp_conffile}"
    # not needed anymore, as we just boot pxelinux.0 and use the same tftpprefix everytime now!!
    #vbox.extra_data['VBoxInternal/Devices/pcnet/0/LUN#0/Config/TFTPPrefix']='/var/www/ubuntu-installer/amd64'
  else # default os == :ubuntu i632
    vbox.os_type_id="Ubuntu"
    File.symlink '/var/www/pxelinux.cfg/default-ubuntu', "/var/www/pxelinux.cfg/#{tftp_conffile}"
    #vbox.extra_data['VBoxInternal/Devices/pcnet/0/LUN#0/Config/TFTPPrefix']='/var/www/ubuntu-installer/i386'
    #vbox.extra_data['VBoxInternal/Devices/pcnet/0/LUN#0/Config/TFTPPrefix']='/var/www/pxe_dust'
  end

  vbox.save
  
end
