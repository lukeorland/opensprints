/*
 * Arduino wiring:
 * 
 * Arduino pin  ATmega168/328 Pin  Connected to
 * -----------  -----------------  ------------
 * digital 2    PD2                Sensor 0
 * digital 3    PD3                Sensor 1
 * digital 4    PD4                Sensor 2
 * digital 5    PD5                Sensor 3
 * 
 * digital 9    PB1                Racer0 Start LED anode, Stop LED cathode
 * digital 10   PB2                Racer1 Start LED anode, Stop LED cathode
 * digital 11   PB3                Racer2 Start LED anode, Stop LED cathode
 * digital 12   PB4                Racer3 Start LED anode, Stop LED cathode
 * 
 */

#include <avr/interrupt.h>  
#include <avr/io.h>

#define NUM_SENSORS	4

int statusLEDPin = 13;
long statusBlinkInterval = 250;
int lastStatusLEDValue = LOW;
long previousStatusBlinkMillis = 0;

boolean mockMode = false;
unsigned long raceStartMillis;
unsigned long currentTimeMillis;

int val = 0;

int racerGoLedPins[NUM_SENSORS] = {9,10,11,12};	// Arduino digital IOs
int sensorPinsArduino[NUM_SENSORS] = {2,3,4,5};	// Arduino digital IOs
int sensorPortDPinsAvr[NUM_SENSORS] = {2,3,4,5};		// Arduino digital IOs
int previousSensorValues;
int currentSensorValues;
unsigned long racerTicks[NUM_SENSORS] = {0,0,0,0};
unsigned long racerFinishTimeMillis[NUM_SENSORS] = {0,0,0,0};

unsigned int racerFinishedFlags = 0;
#define ALL_RACERS_FINISHED_MASK	0x0F // binary 00001111

unsigned long lastCountDownMillis;
int lastCountDown;

unsigned int charBuff[8];
unsigned int charBuffLen = 0;
boolean isReceivingRaceLength = false;

int raceLengthTicks = 1000;
int previousFakeTickMillis = 0;

int updateInterval = 250;		// milliseconds
unsigned long lastUpdateMillis = 0;

int state;
enum
{
	STATE_IDLE,
	STATE_COUNTDOWN,
	STATE_RACING,
};

ISR(PCINT2_vect)
{
	currentTimeMillis = millis() - raceStartMillis;
  unsigned int newRisingEdges;

	// Register rising edge events
	previousSensorValues = currentSensorValues;
	currentSensorValues = PIND;
	newRisingEdges = (previousSensorValues ^ currentSensorValues) & currentSensorValues;
	for(int i=0; i < NUM_SENSORS; i++)
	{
		if(newRisingEdges & (1<<sensorPortDPinsAvr[i]))
		{
			racerTicks[i]++; // ???
		}
		if(racerTicks[i] == raceLengthTicks)
		{
			racerFinishTimeMillis[i] = currentTimeMillis;
		}
	}
}
void setup()
{
  Serial.begin(115200); 
  pinMode(statusLEDPin, OUTPUT);
  for(int i=0; i < NUM_SENSORS; i++)
  {
		pinMode(racerGoLedPins[i], OUTPUT);
		digitalWrite(racerGoLedPins[i], LOW);
    pinMode(sensorPinsArduino[i], INPUT);
    digitalWrite(sensorPinsArduino[i], HIGH);		// set weak pull-up
  }
	// make digital IO pins 2,3,4,5 pin change interrupts
	PCICR |= (1 << PCIE2);
	PCMSK2 |= (1 << PCINT18);
	PCMSK2 |= (1 << PCINT19);
	PCMSK2 |= (1 << PCINT20);
	PCMSK2 |= (1 << PCINT21);

	state = STATE_IDLE;
}

void blinkLED()
{
  if (millis() - previousStatusBlinkMillis > statusBlinkInterval)
	{
    previousStatusBlinkMillis = millis();
    lastStatusLEDValue = !lastStatusLEDValue;
    digitalWrite(statusLEDPin, lastStatusLEDValue);
  }
}

void checkSerial(){
  if(Serial.available())
	{
    val = Serial.read();
    if(isReceivingRaceLength)
		{
      if(val != '\r')
			{
        charBuff[charBuffLen] = val;
        charBuffLen++;
      }
      else if(charBuffLen==2)
			{
        // received all the parts of the distance. time to process the value we received.
        // The maximum for 2 chars would be 65 535 ticks.
        // For a 0.25m circumference roller, that would be 16384 meters = 10.1805456 miles.
        raceLengthTicks = charBuff[1] * 256 + charBuff[0];
        isReceivingRaceLength = false;
        Serial.print("OK ");
        Serial.println(raceLengthTicks,DEC);
      }
      else
			{
        Serial.println("ERROR receiving tick lengths");
      }
    }
    else
		{
      if(val == 'l')
			{
          charBuffLen = 0;
          isReceivingRaceLength = true;
      }
      if(val == 'v')
			{
        Serial.print("basic-1");
      }
      if(val == 'g')
			{
				state = STATE_COUNTDOWN;
        lastCountDown = 4;
        lastCountDownMillis = millis();
      }
      else if(val == 'm')
			{
        // toggle mock mode
        mockMode = !mockMode;
      }
      if(val == 's')
			{
				for(int i=0; i < NUM_SENSORS; i++)
				{
					digitalWrite(racerGoLedPins[i],LOW);
				}
				state = STATE_IDLE;
      }
    }
  }
}

void handleStates()
{
	long systemTime = millis();
  if(state == STATE_COUNTDOWN)
	{
    if((systemTime - lastCountDownMillis) > 1000)
		{
      lastCountDown -= 1;
      lastCountDownMillis = systemTime;
    }
    if(lastCountDown == 0)
		{
			raceStartMillis = systemTime;
			for(int i=0; i < NUM_SENSORS; i++)
			{
				racerFinishedFlags=0;
				racerTicks[i] = 0;
				racerFinishTimeMillis[i] = 0;
				digitalWrite(racerGoLedPins[i],HIGH);
			}
			state = STATE_RACING;
    }
  }
	if (state == STATE_RACING)
	{
    currentTimeMillis = systemTime - raceStartMillis;
		for(int i=0; i < NUM_SENSORS; i++)
		{
      if(!mockMode)
			{
				if(!(racerFinishedFlags & (1<<i)))
				{
          if(racerTicks[i] >= raceLengthTicks)
					{
            Serial.print(i);
            Serial.print("f: ");
            Serial.println(racerFinishTimeMillis[i], DEC);
            digitalWrite(racer0GoLedPin+i,LOW);
						racerFinishedFlags |= (1<<i);
          }
				}
			}
			else
			{
        if(currentTimeMillis - lastUpdateMillis > updateInterval)
				{
          racerTicks[i]+=(i+1);
          if(racerFinishTimeMillis[i] == 0 && racerTicks[i] >= raceLengthTicks)
					{
            racerFinishTimeMillis[i] = currentTimeMillis;          
            Serial.print(i);
            Serial.print("f: ");
            Serial.println(racerFinishTimeMillis[i], DEC);
            digitalWrite(racer0GoLedPin+i,LOW);
          }
        }
      }
    }
		if(racerFinishedFlags == ALL_RACERS_FINISHED_MASK)
		{
			state = STATE_IDLE;
		}
		// Print status update
		if(currentTimeMillis - lastUpdateMillis > updateInterval)
		{
			lastUpdateMillis = currentTimeMillis;
			for(int i=0; i < NUM_SENSORS; i++)
			{
				Serial.print(i);
				Serial.print(": ");
				Serial.println(racerTicks[i], DEC);
			}
			Serial.print("t: ");
			Serial.println(currentTimeMillis, DEC);
		}
  }
}

void loop()
{
  blinkLED();
  checkSerial();
	handleStates();
}

