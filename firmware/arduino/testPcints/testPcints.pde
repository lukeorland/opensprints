int pin2state;
int pin3state;
int pin4state;
int pin5state;

void setup()
{
	pinMode(2, OUTPUT);
	pinMode(3, OUTPUT);
	pinMode(4, OUTPUT);
	pinMode(5, OUTPUT);

	digitalWrite(2, pin2state = LOW);
	digitalWrite(3, pin3state = LOW);
	digitalWrite(4, pin4state = LOW);
	digitalWrite(5, pin5state = LOW);
}

void loop()
{
	static unsigned long lastTime;
	static unsigned long thisTime;
	lastTime = thisTime;
	thisTime = millis();

	if(thisTime != lastTime)
	{
		if(thisTime % 25 == 0)
		{
			digitalWrite(2, pin2state = !pin2state);
		}
		if(thisTime % 50 == 0)
		{
			digitalWrite(3, pin3state = !pin3state);
		}
		if(thisTime % 100 == 0)
		{
			digitalWrite(4, pin4state = !pin4state);
		}
		if(thisTime % 200 == 0)
		{
			digitalWrite(5, pin5state = !pin5state);
		}
	}
}
