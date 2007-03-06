require 'serialport.so'

sp = SerialPort.new('/dev/ttyUSB0', 115200, 8, 1, SerialPort::NONE)
t_start = Time.now.to_f
t_then = t_start
t_now = t_start
while true do
  if sp.gets
    t_now = Time.now.to_f
    puts "rider-one-tick: #{t_now-t_start}" if (t_now-t_then)>0.05
  end
  t_then = t_now
end

sp.close