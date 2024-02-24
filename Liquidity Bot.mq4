//+------------------------------------------------------------------+
//|                                                Liquidity Bot.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Input parameters
input int PivotPointLength = 12;            // Pivot point length
input int LiquidityValidity = 7;            // Liquidity validity
input bool UsePivotLength = true;           // Use pivot length for liquidity validity
input color HHLLColor = clrDodgerBlue;      // Color for HH and HL points
input color LLHIColor = clrOrange;          // Color for LL and LH points

// Global variables
double HH, HL, LL, LH;                      // Variables to store HH, HL, LL, LH points
int HHIndex, HLIndex, LLIndex, LHIndex;      // Variables to store corresponding indices
double lastHigh, lastLow;                   // Variables to store last high and low
bool uptrend, downtrend;                    // Flags to track trend direction

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialization code here
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Deinitialization code here
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Get current high and low
   double currentHigh = High[0];
   double currentLow = Low[0];

   // Check for HH, HL, LL, LH points
   if(currentHigh > lastHigh)
     {
      HH = currentHigh;
      HHIndex = 0;
      lastHigh = currentHigh;
     }
   else if(currentHigh < lastHigh)
     {
      LH = currentHigh;
      LHIndex = 0;
      lastHigh = currentHigh;
     }

   if(currentLow > lastLow)
     {
      HL = currentLow;
      HLIndex = 0;
      lastLow = currentLow;
     }
   else if(currentLow < lastLow)
     {
      LL = currentLow;
      LLIndex = 0;
      lastLow = currentLow;
     }

   // Calculate trend based on pivot points
   if(HH > LL)
     {
      uptrend = true;
      downtrend = false;
     }
   else if(HH < LL)
     {
      uptrend = false;
      downtrend = true;
     }
   else
     {
      uptrend = false;
      downtrend = false;
     }

   // Identify liquidity points
   int barsSinceHigh = Bars - HHIndex;
   int barsSinceLow = Bars - LLIndex;

   if(barsSinceHigh <= LiquidityValidity && uptrend)
     {
      // Draw liquidity point for uptrend
      ObjectCreate(0, "LiquidityPoint", OBJ_ARROW, 0, Time[0], Low[0]);
      ObjectSetInteger(0, "LiquidityPoint", OBJPROP_COLOR, HHLLColor);
      ObjectSetInteger(0, "LiquidityPoint", OBJPROP_ARROWCODE, SYMBOL_ARROWUP);
     }
   else if(barsSinceLow <= LiquidityValidity && downtrend)
     {
      // Draw liquidity point for downtrend
      ObjectCreate(0, "LiquidityPoint", OBJ_ARROW, 0, Time[0], High[0]);
      ObjectSetInteger(0, "LiquidityPoint", OBJPROP_COLOR, LLHIColor);
      ObjectSetInteger(0, "LiquidityPoint", OBJPROP_ARROWCODE, SYMBOL_ARROWDOWN);
     }
  }
