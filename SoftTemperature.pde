// Configurable parameters.

const unsigned int TEMPERATURE_PIN = 0;
const float INPUT_VOLTAGE = 5.0;

const unsigned int OUTPUT_PERIOD_MS = 1000;
const boolean DISPLAY_TIME = false;

const unsigned int MOVING_AVERAGE_FILTER_SIZE = 10;

// Characteristics of the temperature sensor.

const float MIN_DEGREES_C = 0.0;
const float MAX_DEGREES_C = 70.0;

const float VOLTS_PER_DEGREE_C = 0.01;
const float VOLTS_AT_MIN_DEGREES_C = 0.5;
const float VOLTS_AT_MAX_DEGREES_C = VOLTS_AT_MIN_DEGREES_C + (MAX_DEGREES_C * VOLTS_PER_DEGREE_C);

// Moving average filter and output timer.

unsigned int filterValues[MOVING_AVERAGE_FILTER_SIZE];
unsigned int currentFilterValue = 0;
unsigned long lastOutputTimeMs = 0;

// Setup and loop.

void setup()
{
  initFilter();
  Serial.begin(9600);
}

void loop()
{
  addReadingToFilter(analogRead(TEMPERATURE_PIN));
  
  if ((millis() - lastOutputTimeMs) >= OUTPUT_PERIOD_MS)
  {
    unsigned int counts = getFilterResult();
    float volts = convertAdcCountsToVolts(counts);
    float celsius = convertVoltsToCelsius(volts);
    float fahrenheit = convertCelsiusToFahrenheit(celsius);
    
    displayTemperature(counts, volts, celsius, fahrenheit);
    displayTime(millis(), lastOutputTimeMs);
    lastOutputTimeMs = millis();
  }
}

// Moving average filter routines.

void initFilter()
{
  for (int i = 0; i < MOVING_AVERAGE_FILTER_SIZE; i++)
  {
    filterValues[i] = 0;
  }
}

void addReadingToFilter(unsigned int counts)
{
  filterValues[currentFilterValue] = counts;
  currentFilterValue = (currentFilterValue + 1) % MOVING_AVERAGE_FILTER_SIZE;
}

unsigned int getFilterResult()
{
  unsigned int sum = 0;
  
  for (int i = 0; i < MOVING_AVERAGE_FILTER_SIZE; i++)
  {
    sum += filterValues[i];
  }
  
  return sum / MOVING_AVERAGE_FILTER_SIZE;
}

// Conversion routines.

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

// Display routines.

void displayTemperature(unsigned int counts, float volts, float celsius, float fahrenheit)
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

void displayTime(unsigned long currentTimeMs, unsigned long lastDisplayTimeMs)
{
  if (DISPLAY_TIME)
  {
    Serial.print("millis = ");
    Serial.print(millis());
    Serial.print(", lastOutputTimeMs = ");
    Serial.println(lastOutputTimeMs);
  }
}

// Mapping routines.

float mapLongToFloat(long x, long inputMin, long inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}

float mapFloatToFloat(float x, float inputMin, float inputMax, float outputMin, float outputMax)
{
  return (x - inputMin) * (outputMax - outputMin) / (inputMax - inputMin) + outputMin;
}
