base_dir = ENV['BASE_DIR']+'/'
errors = []
require 'yaml'
unless defined? Shoes
  exit "Install shoes: http://code.whytheluckystiff.net/shoes/"
end

begin
  options = YAML::load(File.read('conf.yml'))
rescue
  alert "You must write a conf.yml. See sample in conf-sample.yml"
end
require base_dir+'lib/racer'
require base_dir+'lib/racer'
require base_dir+'lib/units/base'
require base_dir+'lib/units/standard'
require base_dir+'lib/secsy_time'
#Kernel::require Dir.pwd+'/lib/serialport.so'
require base_dir+"lib/sensors/#{options['sensor']['type']}_sensor"
SENSOR_LOCATION = options['sensor']['device']
RACE_DISTANCE = options['race_distance'].meters.to_km
RED_WHEEL_CIRCUMFERENCE = options['roller_circumference']['red'].mm.to_km
BLUE_WHEEL_CIRCUMFERENCE = options['roller_circumference']['blue'].mm.to_km
TITLE = options['title']

if options['units'] == 'standard'
  UNIT_SYSTEM = :mph
else    
  UNIT_SYSTEM = :kmph
end

class Race
  def initialize(shoes_instance, distance, update_area)
    @shoes_instance = shoes_instance
#    blue = @shoes_instance.ask "Who is on the blue bike?"
#    red = @shoes_instance.ask "Who is on the red bike?"
    @red = Racer.new(:wheel_circumference => RED_WHEEL_CIRCUMFERENCE,
                     :name => "racer1",
                     :units => UNIT_SYSTEM)
    @blue = Racer.new(:wheel_circumference => BLUE_WHEEL_CIRCUMFERENCE,
                      :name => "racer2",
                      :units => UNIT_SYSTEM)
    @bar_size = 800-2*60
    @race_distance = distance
    @update_area = update_area
  end

  def continue?; @continue end

  def refresh
    unless @started
      @queue = Queue.new
      @sensor = Sensor.new(@queue, SENSOR_LOCATION)
      @sensor.start
      @started=true
      @continue = true
    end
    partial_log = []
    @queue.length.times do
      q = @queue.pop
      if q =~ /;/
        partial_log << q
      end
    end
    if (partial_log=partial_log.grep(/^[12]/)).any?
      if (blue_log = partial_log.grep(/^2/))
        @blue.update(blue_log)
      end
      if (red_log = partial_log.grep(/^1/))
        @red.update(red_log)
      end
      @update_area.clear do
        @shoes_instance.stroke gray 0.5
        @shoes_instance.strokewidth 4
        @shoes_instance.line 60-4,280,60-4,380
        @shoes_instance.line 800-60+4,280,800-60+4,380
        blue_progress = @bar_size*percent_complete(@blue)
        @shoes_instance.stroke "#00F"
        @shoes_instance.fill "#FEE".."#32F", :angle => 90, :radius => 10
        @shoes_instance.rect 60, 300, blue_progress, 20 
        
        red_progress = @bar_size*percent_complete(@red)
        @shoes_instance.stroke "#F00"
        @shoes_instance.fill "#FEE".."#F23", :angle => 90, :radius => 10
        @shoes_instance.rect 60, 340, red_progress, 20 
        if @blue.distance>RACE_DISTANCE and @red.distance>RACE_DISTANCE
          winner = (@red.tick_at(@race_distance)<@blue.tick_at(@race_distance)) ? "RED" : "BLUE"
          @shoes_instance.title "#{winner} WINS!!!\n", :align => "center",
            :top => 380, :width => 800 
          @shoes_instance.title "red: #{@red.tick_at(@race_distance)}, blue: #{@blue.tick_at(@race_distance)}",
            :align => 'center', :top => 450, :width => 800
          @sensor.stop
          @continue = false
        end
      end    
    end
  end

  def percent_complete(racer)
    [1.0, racer.distance/@race_distance.to_f].min
  end
end


Shoes.app :width => 800, :height => 600 do
  stack{
    image "track.jpg", :top => -450
  #  stroke magenta
    banner TITLE, :top => 150, :align => "center", :background => magenta
    @update_area = stack {}
  race = lambda do
    @start.hide
    r = Race.new(self, RACE_DISTANCE, @update_area)
    @countdown = 5
    @start_time = Time.now+5
    count_box = stack{ @label = banner "#{@countdown}..." }
    animate(14) do
      @now = Time.now
      if @now < @start_time
        count_box.clear do
          banner "#{(@start_time-@now).round}..."
        end
      else
        count_box.remove
        r.refresh
        @start.show unless r.continue?
      end
    end
  end
    @start = button("Start Race") {
      race.call
    }

    button("Quit") { exit }
  }
end
