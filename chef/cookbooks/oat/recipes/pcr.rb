#should be run after enabling tpm in bios, tboot was installed and tpm become fully initialised by oat agent
#fetching all the pcr values from tpm
File.open("/sys/class/misc/tpm0/device/pcrs", "r") do |pcrs|
  while (line = pcrs.gets)
    line=line.split(":")
    pcr_n=line[0].split("-")[1].to_i
    pcr_v=line[1].delete(' ')
    node[:inteltxt][:pcr][pcr_n]=pcr_v.strip
  end
end
node.save
