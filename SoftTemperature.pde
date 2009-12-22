// ----------------------------------------------------------------------------
// SoftTemperature
// Revision 1.0
// December 21, 2009
//
// Sense temperature and change the color of an LED in response.  Designed for
// the LilyPad Arduino.
//
// Jon Speicher
// jonathan@hackpittsburgh.org
// http://www.hackpittsburgh.org
//
// ----------------------------------------------------------------------------

// These items tell your program the characteristics of your temperature sensor.
// They can be found by reading the datasheet that comes with your sensor.  The
// values here are specific to the LilyPad's temperature sensor module.

const float MIN_DEGREES_C = 0.0;
const float MAX_DEGREES_C = 70.0;

const float VOLTS_PER_DEGREE_C = 0.01;
const float VOLTS_AT_MIN_DEGREES_C = 0.5;
const float VOLTS_AT_MAX_DEGREES_C = VOLTS_AT_MIN_DEGREES_C + (MAX_DEGREES_C * VOLTS_PER_DEGREE_C);

// These items tell your program where the temperature sensor module and the LED
// module are connected to your LilyPad.  The temperature sensor should connect
// to an analog input pin and the LED should connect to three digital pins that
// have PWM capabilities.

const unsigned int TEMPERATURE_PIN = 0;
const unsigned int RED_LED_PIN = 9;
const unsigned int GREEN_LED_PIN = 10;
const unsigned int BLUE_LED_PIN = 11;

// This item tells your program what the input voltage to your LilyPad is.  It
// is used in the calculation of the current temperature.  The LilyPad can run
// with 3.3 volts (like a coin cell battery) or with 5 volts (like a USB cable
// connected to your computer).  If this value isn't set properly, your program
// won't calculate temperature correctly.

const float INPUT_VOLTAGE = 5.0;

// The program will print temperatures and other debugging information to the
// Serial Monitor periodically.  The first value below specifies how often it,
// in milliseconds, the printout occurs.  1000 milliseconds equals one second.
// The second value remembers when the last printout was.

const unsigned int SERIAL_MONITOR_OUTPUT_PERIOD_MS = 1000;
unsigned long lastOutputTimeMs = 0;

// The readings from the temperature sensor module are sensitive and can fluctuate
// rapidly.  To keep the temperature from jumping around, the program averages the
// last few samples from the sensor (this is called a "moving average filter").  
// These items contain the last few samples and remember where to put the next 
// sample (this is known as a "circular buffer").

const unsigned int FILTER_SIZE = 10;
unsigned int filterBuffer[FILTER_SIZE];
unsigned int filterBufferCurrentIndex = 0;

// Setup is called once when the program starts.

void setup()
{
  initFilter();           // Initialize our temperature filter.
  Serial.begin(9600);
}

// Loop is called repeatedly as the program runs.

void loop()
{
  // Read the temperature and add it to the filter.
  
  addValueToFilter(analogRead(TEMPERATURE_PIN));     
  
  // Get the current temperature in degrees Fahrenheit from the filter.
  
  float temperature = getTemperatureInFahrenheit();
  
  // If it's time to print out the debug information to the serial monitor, do it.
  
  if ((millis() - lastOutputTimeMs) >= SERIAL_MONITOR_OUTPUT_PERIOD_MS)
  {
    printDebugToSerialMonitor();
    lastOutputTimeMs = millis();
  }
}

// These functions are used to interact with the moving average filter.  They
// allow the program to store a number of values and to determine their average,
// using a mechanism called a circular buffer.

void initFilter()
{
  for (int i = 0; i < FILTER_SIZE; i++)
  {
    filterBuffer[i] = 0;
  }
}

void addValueToFilter(unsigned int value)
{
  filterBuffer[filterBufferCurrentIndex] = value;
  filterBufferCurrentIndex = (filterBufferCurrentIndex + 1) % FILTER_SIZE;
}

unsigned int getFilterResult()
{
  unsigned int sum = 0;
  
  for (int i = 0; i < FILTER_SIZE; i++)
  {
    sum += filterBuffer[i];
  }
  
  return sum / FILTER_SIZE;
}

// The temperature sensor produces an output voltage that corresponds to the
// sensed temperature.  The LilyPad sees this voltage as an analog-to-digital
// conversion in units known as counts, that range from 0 - 1023.  These functions
// convert from ADC counts to several intermediate units, ending with degrees
// Fahrenheit.

float convertAdcCountsToVolts(unsigned int counts)
{
  return mapLongToFloat(counts, 0, 1023, 0.0, INPUT_VOLTAGE);
}

float convertVoltsToCelsius(float volts)
{
  return mapFloatToFloat(volts, VOLTS_AT_MIN_DEGREES_C, VOLTS_AT_MAX_DEGREES_C, MIN_DEGREES_C, MAX_DEGREES_C);
}

float convertCelsiusToFahrenheit(float celsius)
{
  return (celsius * 1.8) + 32;
}

// This function reads the value of the filter, converts it into degrees Fahrenheit,
// and returns it.

float getTemperatureInFahrenheit()
{
  unsigned int counts = getFilterResult();
  float volts = convertAdcCountsToVolts(counts);
  float celsius = convertVoltsToCelsius(volts);
  return convertCelsiusToFahrenheit(celsius);
}

// These functions print information to the serial monitor for debugging
// purposes.

void printDebugToSerialMonitor()
{
  unsigned int counts = getFilterResult();
  float volts = convertAdcCountsToVolts(counts);
  float celsius = convertVoltsToCelsius(volts);
  float fahrenheit = convertCelsiusToFahrenheit(celsius);
   
  printTemperatureToSerialMonitor(counts, volts, celsius, fahrenheit);
}

void printTemperatureToSerialMonitor(unsigned int counts, float volts, float celsius, float fahrenheit)
{
  Serial.print("Counts = ");
  Serial.print(counts);
  Serial.print(", Volts = ");
  Serial.print(volts);
  Serial.print(", Celsuis = ");
  Serial.print(celsius);
  Serial.print(", Fahrenheit = ");
  Serial.println(fahrenheit);
}

// The Arduino library provides a helpful function called map that scales values
// into different ranges, but the built-in map only works with certain data types
// (long, to be exact).  We would like to work with other data types, so we wrote
// our own alternate versions.

float mapLongToFloat(long x, long inputMin, long inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}

float mapFloatToFloat(float x, float inputMin, float inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}
