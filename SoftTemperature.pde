// ----------------------------------------------------------------------------
// SoftTemperature
// Revision 1.4
// January 9, 2009
//
// Sense temperature and change the color of an LED in response.  Designed for
// the LilyPad Arduino.
//
// Jon Speicher
// jonathan@hackpittsburgh.org
// http://www.hackpittsburgh.org
//
// This content is made available under the Creative Commons Attribution-
// Noncommercial-Share Alike 3.0 Unported license.
//
// http://creativecommons.org/licenses/by-nc-sa/3.0
//
// ----------------------------------------------------------------------------

// These items tell your program the characteristics of your temperature sensor.  They can be found 
// by reading the datasheet that comes with your sensor.  The values here are specific to the 
// LilyPad's temperature sensor module.

const float MIN_DEGREES_C = 0.0;
const float MAX_DEGREES_C = 70.0;

const float VOLTS_PER_DEGREE_C = 0.01;
const float VOLTS_AT_MIN_DEGREES_C = 0.5;
const float VOLTS_AT_MAX_DEGREES_C = VOLTS_AT_MIN_DEGREES_C + (MAX_DEGREES_C * VOLTS_PER_DEGREE_C);

// These items tell your program where the temperature sensor module, the LED module, and the soft
// switch are connected to your LilyPad.  The temperature sensor should connect to an analog input 
// pin, the LED should connect to three digital pins that have PWM capabilities, and the switch
// should connect to a digital input pin.

const unsigned int TEMPERATURE_PIN = 0;
const unsigned int RED_LED_PIN = 11;
const unsigned int GREEN_LED_PIN = 9;
const unsigned int BLUE_LED_PIN = 10;
const unsigned int SWITCH_PIN = 7;

// This item tells your program what the input voltage to your LilyPad is.  It is used in the 
// calculation of the current temperature.  The LilyPad can run with 3.3 volts (like a coin cell 
// battery) or with 5 volts (like a USB cable connected to your computer).  If this value isn't set 
// properly, your program won't calculate temperature correctly.

const float INPUT_VOLTAGE = 3.3;

// The readings from the temperature sensor module are sensitive and can fluctuate rapidly.  To keep 
// the temperature from jumping around, the program averages the last few samples from the sensor 
// (this is called a "moving average filter").  These items contain the last few samples and 
// remember where to put the next sample (this is known as a "circular buffer").

const unsigned int FILTER_SIZE = 10;
unsigned int filterBuffer[FILTER_SIZE];
unsigned int filterBufferCurrentIndex = 0;

// We need a way to manipulate colors and to specify colors for the LED output.  We'll use a byte 
// for red, a byte for green, and a byte for blue (this is often called 24-bit color because there 
// are eight bits in a byte).  We'll pack these bytes into one variable for easy manipulation, and 
// we can specify colors "web-style" with a six-digit hexadecimal value.  For example, 0xFF0080 
// specifies a red value of 255, a green value of 0, and a blue value of 128.  We want some macros 
// to help us break a color into its components and to assemble one from components as well.  We
// need to use an unsigned long to hold a color, which is the only data type capable of holding 24 
// bits (int is 16 bits on Arduino, long is 32).

#define RED(color) (((color) >> 16) & 0xFF)
#define GREEN(color) (((color) >> 8) & 0xFF)
#define BLUE(color) ((color) & 0xFF)

#define RGB(red, green, blue) (((unsigned long) red << 16) | ((unsigned long) green << 8) | blue)

// We need to define the color that we will use when blinking the temperature.  We'll also define
// the delays used between blinks and between digits.

const unsigned long TEMPERATURE_BLINK_COLOR = 0xFFFFFF;
const unsigned int TEMPERATURE_BLINK_DELAY_MS = 500;
const unsigned int TEMPERATURE_DIGIT_DELAY_MS = 1000;

// Now we need a way to specific what color should be displayed at what temperature.  For our
// program, we'll use a reverse rainbow, with violet being displayed at the coldest temperature we
// can sense and red being displayed at the highest reasonable temperature we can sense.  The 
// program will compute intermediate temperatures appropriately.  The temperature will be specified
// in degrees Fahrenheit.  A good site for looking up color codes is:
//
//    http://cloford.com/resources/colours/500col.htm

struct TEMP_COLOR_PAIR
{
  float fahrenheit;
  unsigned long color;
};

TEMP_COLOR_PAIR COLOR_MAP[] =
{
  {32, 0xEE82EE},  // violet
  {41, 0x4B0082},  // indigo
  {50, 0x0000FF},  // blue
  {59, 0x00FF00},  // green
  {68, 0xFFFF00},  // yellow
  {77, 0xFF7F00},  // orange
  {86, 0xFF0000}   // red
};

const unsigned int COLOR_MAP_SIZE = sizeof(COLOR_MAP) / sizeof(COLOR_MAP[0]);

// The program will print temperatures and other debugging information to the Serial Monitor 
// periodically.  The first value below specifies how often, in milliseconds, the printout occurs.  
// 1000 milliseconds equals one second.  The second value remembers when the last printout was.

const unsigned int SERIAL_MONITOR_OUTPUT_PERIOD_MS = 1000;
unsigned long lastOutputTimeMs = 0;

// Setup is called once when the program starts.

void setup()
{
  // Initialize the temperature filter.
  
  initFilter();
  
  // Initialize the switch.  Set the switch as active low and activate the internal pullup resistor.
  
  pinMode(SWITCH_PIN, INPUT);
  digitalWrite(SWITCH_PIN, HIGH);
  
  // Enable the Serial Monitor.
  
  Serial.begin(9600);
}

// Loop is called repeatedly as the program runs.

void loop()
{
  // Read the temperature and add it to the filter.
  
  addValueToFilter(analogRead(TEMPERATURE_PIN));  
  
  // Get the current temperature in degrees Fahrenheit from the filter.
  
  float temperature = getTemperatureInFahrenheit();
  
  // If the switch is pressed, blink out the temperature.  Otherwise, show the proper color for the
  // temperature.
  
  if (isSwitchPressed())
  {
    blinkTemperature(temperature);
  }
  else
  {
    unsigned long color = findColorForTemperature(temperature);
    setLedColor(color);
  }
  
  // If it's time to print out the debug information to the serial monitor, do it.
  
  if ((millis() - lastOutputTimeMs) >= SERIAL_MONITOR_OUTPUT_PERIOD_MS)
  {
    printDebugToSerialMonitor();
    lastOutputTimeMs = millis();
  }
}

// These functions are used to interact with the moving average filter.  They allow the program to 
// store a number of values and to determine their average, using a mechanism called a circular 
// buffer.

void initFilter()
{
  for (unsigned int i = 0; i < FILTER_SIZE; i++)
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
  
  for (unsigned int i = 0; i < FILTER_SIZE; i++)
  {
    sum += filterBuffer[i];
  }
  
  return sum / FILTER_SIZE;
}

// The temperature sensor produces an output voltage that corresponds to the sensed temperature. 
// The LilyPad sees this voltage as an analog-to-digital conversion in units known as counts that 
// range from 0 - 1023.  These functions convert from ADC counts to several intermediate units, 
// ending with degrees Fahrenheit.

float convertAdcCountsToVolts(unsigned int counts)
{
  return mapLongToFloat(counts, 0, 1023, 0.0, INPUT_VOLTAGE);
}

float convertVoltsToCelsius(float volts)
{
  // Map the voltage into the temperature range we're interested in.
  
  float celsius = mapFloatToFloat(volts, VOLTS_AT_MIN_DEGREES_C, VOLTS_AT_MAX_DEGREES_C, MIN_DEGREES_C, MAX_DEGREES_C);
  
  // Because the range of the analog input is greater than the output range of the sensor (0 - 3.3 
  // or 5 volts versus 0 - 1.2 volts) it is possible that the temperature in Celsuis will come back
  // weird if the sensor is unconnected or something is wrong with the circuit.  This is because the
  // map calculations go crazy if you tell them to map a value that is outside of the minimum and
  // maximum range that we specify.  If we get one of these out-of-range values something is
  // definitely wrong, but we'll fix it here by clamping the temperature to the min or the max
  // appropriately.
  
  if (celsius < MIN_DEGREES_C)
  {
      celsius = MIN_DEGREES_C;
  }
  else if (celsius > MAX_DEGREES_C)
  {
      celsius = MAX_DEGREES_C;
  }
  
  return celsius;
}

float convertCelsiusToFahrenheit(float celsius)
{
  return (celsius * 1.8) + 32;
}

// This function reads the value of the filter, converts it into degrees Celsius, and returns it.

float getTemperatureInCelsius()
{
  unsigned int counts = getFilterResult();
  float volts = convertAdcCountsToVolts(counts);
  return convertVoltsToCelsius(volts);
}

// This function reads the value of the filter, converts it into degrees Fahrenheit, and returns it.

float getTemperatureInFahrenheit()
{
  float celsius = getTemperatureInCelsius();
  return convertCelsiusToFahrenheit(celsius);
}

// This function returns true if the switch is pressed and false otherwise.  Because the switch is
// active low, the result of the digital read is negated.

boolean isSwitchPressed()
{  
  return !digitalRead(SWITCH_PIN);
}

// This function blinks the temperature using the LED.  The hundreds (if set), tens, and ones place 
// are blinked out separately with a short delay in between.

void blinkTemperature(float fahrenheit)
{
  // We need to be a little tricky here.  It's not really possible for us to display any place that 
  // is zero, so we may need to tweak the temperature a little bit up or down to get one that can be 
  // displayed with blinks.  Less accurate, more pretty.
  
  float adjustedFahrenheit = adjustTemperatureForDisplay(fahrenheit);
  
  // Find the hundreds, tens, and ones places.
  
  unsigned int hundreds = adjustedFahrenheit / 100;
  
  // If there was a hundreds place, subtract the proper amount from the temperature or else our tens
  // calculation will be inaccurate.
  
  if (hundreds > 0)
  {
    adjustedFahrenheit = adjustedFahrenheit - (hundreds * 100);
  }
  
  unsigned int tens = adjustedFahrenheit / 10;
  unsigned int ones = (int) adjustedFahrenheit % 10;
  
  printBlinkToSerialMonitor(fahrenheit, hundreds, tens, ones);
  
  // Now blink the LED.
  
  if (hundreds > 0)
  {
    blinkLed(hundreds, TEMPERATURE_BLINK_COLOR, TEMPERATURE_BLINK_DELAY_MS);
    delay(TEMPERATURE_DIGIT_DELAY_MS);
  }
  
  if (tens > 0)
  {
    blinkLed(tens, TEMPERATURE_BLINK_COLOR, TEMPERATURE_BLINK_DELAY_MS);
    delay(TEMPERATURE_DIGIT_DELAY_MS);
  }
  
  blinkLed(ones, TEMPERATURE_BLINK_COLOR, TEMPERATURE_BLINK_DELAY_MS);
  delay(TEMPERATURE_DIGIT_DELAY_MS);
}

// This function adjusts the input temperature to a temperature that is suitable for a blinked 
// display.  Specifically it ensures that no significant digit places contain zeroes, since those 
// cannot be displayed via blinking.

float adjustTemperatureForDisplay(float temperature)
{
  // Adjust the temperature.
  
  if ((temperature >= 100) && (temperature < 111))
  {
    // If the temperature at or above 100 but below 111, this means that the tens place or the ones 
    // place are potentially zero.  The closest temperature with all non-zero digits is 111.
    
    temperature = 111;
  }
  else if (((int) temperature % 10) == 0)
  {
    // If the ones place is zero, increment the temperature by one degree.
    
    temperature++;
  }
  
  return temperature;
}

// This function blinks the LED on and off using the specified number of blinks, color, and delay.

void blinkLed(unsigned int times, unsigned long color, unsigned int delayMs)
{
  setLedColor(0);
  delay(delayMs);
  
  while (times > 0)
  {
    setLedColor(color);
    delay(delayMs);
    
    setLedColor(0);
    delay(delayMs);
    
    times--;
  }
}

// This function finds the color that corresponds to the provided temperature and returns it.

unsigned long findColorForTemperature(float fahrenheit)
{
  unsigned int baseColorIndex = 0;
  
  // Search through the color map to find the entry with a temperature that is less than or equal to
  // the specified temperature.  Don't allow the index to exceed the size of the color map, or
  // terrible things will happen.
  
  while (((baseColorIndex + 1) < COLOR_MAP_SIZE) && 
         (COLOR_MAP[baseColorIndex + 1].fahrenheit <= fahrenheit))
  {
    baseColorIndex++;
  }
  
  // If the specified temperature is off either end of the scale, just display the color at that end
  // of the scale.  If it's somewhere in the middle, we need to compute the actual color
  // algorithmically since it may be between two specified entries in the map.  Doing this makes the
  // color change very smoothly as the temperature changes.
  
  if ((fahrenheit < COLOR_MAP[0].fahrenheit) || 
      (fahrenheit > COLOR_MAP[COLOR_MAP_SIZE - 1].fahrenheit))
  {
    return COLOR_MAP[baseColorIndex].color;
  }
  else
  {
    return interpolateColor(fahrenheit, baseColorIndex);
  }
}

// Our color map specifies a color for only a few points along the temperature axis.  The actual
// temperature is not likely to fall exactly on one of those points.  This function will compute a
// color that corresponds to the current temperature by picking a color that is somewhere between
// the colors for the two temperatures surrounding it in the color map.  Doing this produces a color
// that changes very smoothly as the temperature changes.

unsigned long interpolateColor(float fahrenheit, unsigned int baseColorIndex)
{
  TEMP_COLOR_PAIR color1 = COLOR_MAP[baseColorIndex];
  TEMP_COLOR_PAIR color2 = COLOR_MAP[baseColorIndex + 1];
  
  byte red = interpolate(fahrenheit, color1.fahrenheit, RED(color1.color), 
                                     color2.fahrenheit, RED(color2.color));
                                     
  byte green = interpolate(fahrenheit, color1.fahrenheit, GREEN(color1.color), 
                                       color2.fahrenheit, GREEN(color2.color));
                                       
  byte blue = interpolate(fahrenheit, color1.fahrenheit, BLUE(color1.color), 
                                      color2.fahrenheit, BLUE(color2.color));
  
  return RGB(red, green, blue);
}

// This function implements a linear interpolation.  Given two points on a line, this function will
// find the y value that corresponds to the provided x value as long as x0 <= x <= x1.

byte interpolate(float x, float x0, byte y0, float x1, byte y1)
{
  return (y0 + ((x - x0) * ((y1 - y0) / (x1 - x0))));
}

// This function changes the LED to the appropriate color.  The color is specified as one value
// containing red, green, and blue information.  The red intensity is in byte 2, green in byte 1,
// and blue in byte 0.  The PWM output is inverted since the LilyPad's RGB LED module is a common-
// anode design.

void setLedColor(unsigned long color)
{  
  analogWrite(RED_LED_PIN, 255 - RED(color));
  analogWrite(GREEN_LED_PIN, 255 - GREEN(color));
  analogWrite(BLUE_LED_PIN, 255 - BLUE(color));
}

// The Arduino library provides a helpful function called map that scales values into different 
// ranges, but the built-in map only works with certain data types (long, to be exact).  We would 
// like to work with other data types, so we wrote our own alternate versions.

float mapLongToFloat(long x, long inputMin, long inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}

float mapFloatToFloat(float x, float inputMin, float inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}

// These functions print information to the serial monitor for debugging purposes.

void printDebugToSerialMonitor()
{
  unsigned int counts = getFilterResult();
  float volts = convertAdcCountsToVolts(counts);
  float celsius = convertVoltsToCelsius(volts);
  float fahrenheit = convertCelsiusToFahrenheit(celsius);
  printTemperatureToSerialMonitor(counts, volts, celsius, fahrenheit);
  
  unsigned long color = findColorForTemperature(fahrenheit);
  printColorToSerialMonitor(color);
  
  Serial.println("");
}

void printBlinkToSerialMonitor(float temperature, int hundreds, int tens, int ones)
{
  Serial.print("Blinking temperature ");
  Serial.print(temperature);
  Serial.print(", Hundreds = ");
  Serial.print(hundreds);
  Serial.print(", Tens = ");
  Serial.print(tens);
  Serial.print(", Ones = ");
  Serial.println(ones);
  Serial.println("");
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

void printColorToSerialMonitor(unsigned long color)
{
  Serial.print("Color = 0x");
  Serial.print(color, HEX);
  Serial.print(", red = ");
  Serial.print(RED(color));
  Serial.print(", green = ");
  Serial.print(GREEN(color));
  Serial.print(", blue = ");
  Serial.println(BLUE(color)); 
}
