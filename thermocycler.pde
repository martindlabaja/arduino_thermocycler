
// ---------------------------------------------------------------------
// PCR 2 temps 2 peltiers
// peltier1 : 12  peltier2 : 5  hbridge1 : 11   hbridge2 : 6  cooling: 7  
// ---------------------------------------------------------------------

#include <max6675.h> // max thermocouple driver
MAX6675 tc1(10, 9, 8);
MAX6675 tc2(4, 3, 2);

unsigned long delta, now;
bool attained, isCooling, isReversed = false;
int state, cycleCount = 0;

int kp_1 = 40;   int ki_1 = 20;   int kd_1 = 150; //90,30,80 int kp_1 = 20;   int ki_1 = 30;   int kd_1 = 150;
int P_1 = 0;    int I_1 = 0;    int D_1 = 0;
float PID_error_1 = 0;
float previous_error_1 = 0;
int pwm_1 = 0;

int kp_2 = 90;   int ki_2 = 30;   int kd_2 = 150; //90,30,80
int P_2 = 0;    int I_2 = 0;    int D_2 = 0;
float PID_error_2 = 0;
float previous_error_2 = 0;
int pwm_2 = 0;

unsigned long elapsedTime, Time, timePrev;

//                RUNNING PARAMETERS
// ----------- temperatures in celsius--------------
int T0 = 0; // 95,55,72, 1min, 1min, 1min --> common parameters
int T1 = 0;
int T2 = 0;
int T3 = 0;
int T4 = 0;
int totalCycles = 3;

int tolerance = 5;  
int set_temperature = 0;
// -------------- times in miliseconds -----------------
unsigned long S0 = 30000;
unsigned long S1 = 30000;
unsigned long S2 = 30000;
unsigned long S3 = 30000;
unsigned long S4 = 30000;

String memory;

void setup() {  
  pinMode(12,OUTPUT); // peltier 1 pwm (main)
  pinMode(5,OUTPUT);  //peltier 2 pwm (lid heating)
  pinMode(11,OUTPUT); //hbridge1 cooling/heating (left)
  pinMode(6,OUTPUT);  //hbridge2 cooling/heating (right)
  pinMode(7,OUTPUT);  // cooling fan2
  pinMode(13,OUTPUT); // mosfet fan1

  digitalWrite(11,HIGH); //hbridge1 DEFAULT STARTUP STATE
  digitalWrite(6,HIGH);  //hbridge2 DEFAULT STARTUP STATE

  Serial.begin(9600);
}

void cooling(bool state) {
  if (state==true) {
    analogWrite(7,255); // start 
    analogWrite(13,255); 
  } else {
    analogWrite(7,0); // stop
    analogWrite(13,0);  
  }  
}

void hbridge(bool heating) {
  if (heating==1){
    digitalWrite(11,LOW);
    digitalWrite(6,LOW);
  } else {
    digitalWrite(11,HIGH);
    digitalWrite(6,HIGH);
  }
}

void loop() {

  // ------------------ SERIAL INPUT ------------------
  if(Serial.available()){
    String rxString = "";
    String strArr[11]; //Set the size of the array to equal the number of values you will be receiveing.
    //Keep looping until there is something in the buffer.
    while (Serial.available()) {
      //Delay to allow byte to arrive in input buffer.
      delay(20);
      //Read a single character from the buffer.
      char ch = Serial.read();
      //Append that single character to a string.
      rxString+= ch;
    }
    int stringStart = 0;
    int arrayIndex = 0;
    for (int i=0; i < rxString.length(); i++){
      //Get character and check if it's our "special" character.
      if(rxString.charAt(i) == ','){
        //Clear previous values from array.
        strArr[arrayIndex] = "";
        //Save substring into array.
        strArr[arrayIndex] = rxString.substring(stringStart, i);
        //Set new string starting point.
        stringStart = (i+1);
        arrayIndex++;
      }
    }
    //Put values from the array into the variables.
    String value0 = strArr[0];
    String value1 = strArr[1];
    String value2 = strArr[2];
    String value3 = strArr[3];
    String value4 = strArr[4];
    String value5 = strArr[5];
    String value6 = strArr[6];
    String value7 = strArr[7];
    String value8 = strArr[8];
    String value9 = strArr[9];
    String value10 = strArr[10];
    //Convert string to int if you need it.
    T0 = value0.toInt();
    T1 = value1.toInt();
    T2 = value2.toInt();
    T3 = value3.toInt();
    T4 = value4.toInt();
    S0 = value5.toInt();
    S1 = value6.toInt();
    S2 = value7.toInt();
    S3 = value8.toInt();
    S4 = value9.toInt();
    totalCycles = value10.toInt();
  }

  // ------------------ TICK ------------------------------------------------------------------------------
    
  float temp = tc1.readCelsius()-2;  
  float temp2 = tc2.readCelsius()-1; 

  cooling(isCooling); // cooling control
  hbridge(isReversed);// h-bridge polarity control
  
  // ------------------ INIT DENATURATION 0 ------------------
  if(state == 0) {            
    set_temperature = T0;  
    if(attained == true) {
      isCooling = true;      
    } else {
      isCooling = true;    
    }
      
    if((temp > T0-tolerance) && (temp < T0+tolerance) && (attained==false)) {
      attained = true;
      now = millis();      
    }

    delta = millis()-now; 

    if((delta > S0) && (attained==true)) {
      delta=0;
      state=1;      
      attained = false; 

      isReversed = false;

      }
  }  
  // ------------------ DENATURATION 1 ------------------
  if(state == 1) {            
    set_temperature = T1;  
    isCooling = true;    
      
    if((temp > T1-tolerance) && (temp < T1+tolerance) && (attained==false)) {
      attained = true;
      now = millis();      
    }

    delta = millis()-now; 

    if((delta > S1) && (attained==true)) {
      delta=0;
      state=2;      
      attained = false; 

      isReversed = true;

      }
  }  
  // ------------------ ANNEALING 2 ------------------
  if(state == 2) {   

    set_temperature = T2;  
    isCooling = true;    

    if((temp > T2-(tolerance-3)) && (temp < T2+(tolerance-3)) && (attained==false)) {
      attained = true;
      now = millis();  
      isReversed = false;    
    }
    delta = millis()-now;
    if((delta > S2 ) && (attained==true)) {
      delta=0;
      state=3;
      attained = false;      
    }
  }  
  // ------------------ EXTENSION 3 ------------------
  if(state == 3) {
       
    set_temperature = T3;   
    isCooling = true;    

    if((temp > T3-tolerance) && (temp < T3+tolerance) && (attained==false)) {
      attained = true;
      now = millis(); 
    }
    delta = millis()-now;
    if((delta > S3) && (attained==true)) {
      delta=0;
      cycleCount += 1;  
      attained = false;
      
      if(cycleCount == totalCycles){
        state=4;  
      }  else {
        state = 1;
      }

      
    }
  }  
  // ------------------ FINAL EXTENSION 4 ------------------
  if(state == 4) {
       
    set_temperature = T4;   
    isCooling = true;    

    if((temp > T4-tolerance) && (temp < T4+tolerance) && (attained==false)) {
      attained = true;
      now = millis(); 
    }
    delta = millis()-now;
    if((delta > S4) && (attained==true)) {
      delta=0;
      state=5;
      attained = false;        
    }
  }  
  // ------------------ FINISHED 5 ------------------
  if(state == 5) {
    set_temperature = 0; 
    if (temp<30) {
      isCooling = false;
    }
  }
  //----------------------------------------
  //                 PID Time
  //----------------------------------------
  timePrev = Time;                            
  Time = millis();                            
  elapsedTime = (Time - timePrev) / 1000;

  //----------------------------------------
  //             PID 1 MAIN
  //----------------------------------------
  if (isReversed==true) {
    PID_error_1 = temp - (set_temperature + 5.5) ;   
  } else {
      PID_error_1 = (set_temperature + 5.5) - temp;
  }
   
  P_1 = 0.01*kp_1 * PID_error_1;     
  I_1 = 0.01*I_1 + (ki_1 * PID_error_1); 
  D_1 = 0.01*kd_1*((PID_error_1 - previous_error_1)/elapsedTime); 
  pwm_1 = P_1 + I_1 + D_1;
 
  if(pwm_1 < 0)
  {    pwm_1 = 0;    }
  if(pwm_1 > 255)  
  {    pwm_1 = 255;  } 
 
  analogWrite(12,(pwm_1));          
 
  previous_error_1 = PID_error_1;    

  //----------------------------------------
  //              PID 2 LID
  //----------------------------------------
  //PID_error_2 = set_temperature - temp2;
  if (isReversed==true) {
    PID_error_2 = temp2 - (set_temperature + 1.5);
  } else {
    PID_error_2 = (set_temperature + 1.5) - temp2;
  }
   
  P_2 = 0.01*kp_2 * PID_error_2;     
  I_2 = 0.01*I_2 + (ki_2 * PID_error_2); 
  D_2 = 0.01*kd_2*((PID_error_2 - previous_error_2)/elapsedTime); 
  pwm_2 = P_2 + I_2 + D_2;
 
  if(pwm_2 < 0)
  {    pwm_2 = 0;    }
  //restriction of LID max throttle
  if(pwm_2 > 150)  
  {    pwm_2 = 150;  } 
 
  analogWrite(5,pwm_2);          

  previous_error_2 = PID_error_2; 

  //----------------------------------------
  //             DEBUG PRINT
  //----------------------------------------

  Serial.print(temp);
  Serial.print(','); 
  Serial.print(temp2);
  Serial.print(','); 
  Serial.print(pwm_1);
  Serial.print(','); 
  Serial.print(pwm_2);
  Serial.print(',');
  Serial.print(set_temperature);
  Serial.print(','); 
  Serial.print(delta/1000);
  Serial.print(','); 
  Serial.print(cycleCount);  
  Serial.print(','); 
  Serial.print(state);  
  Serial.println('>');   
  delay(200);
}



// peltier1 : 12  peltier2 : 5  hbridge1 : 11   hbridge2 : 6  cooling: 7  
