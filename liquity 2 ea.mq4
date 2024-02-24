//|                                                Liquidity Bot.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict



// Input parameters
input int LiquidityValidity = 7;            // Liquidity validity
input color HHLLColor = clrDodgerBlue;      // Color for HH and HL points
input color LLHIColor = clrOrange;          // Color for LL and LH points

input int Consecutiveloss = 2;
input int Delay_Bar = 4;
input int InpDelayBars = 4;
input double RangingStopLoss = 40.0;
input double RangingTakeProfit = 45.0;
input double TrendingStopLoss = 40.0;
input double TrendingTakeProfit = 50.0;
input double Lot_Step = 2;
input double Base_Lots = 0.01;
input string TradeComment = "RL";
input int TheMagicNumber = 38467;
double Dynamic_Lots = Base_Lots;

double TakeProfit;
double StopLoss;

int                     lastTradeBar = 0; // Declare lastTradeBar as a global variable
int                     consecutiveLossTrades = 0; // Declare consecutiveLossTrades as a global variable
datetime                LastTradeTime = 0;

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
    int result = ValidateInputs();
    if (result != INIT_SUCCEEDED)
        return (result);

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| This is a function to validate the inputs                        |
//+------------------------------------------------------------------+
int ValidateInputs()
{
    // Validate input parameters
    if (LiquidityValidity <= 0 || Consecutiveloss <= 0 || Delay_Bar <= 0 || InpDelayBars <= 0 || Base_Lots <= 0 || TheMagicNumber <= 0)
    {
        Print("Invalid input parameters");
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{

}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!IsNewBar())
        return;

    int barsSinceLastClosedTrade = BarsSinceLastClosedTrade();
    if (barsSinceLastClosedTrade < InpDelayBars)
        return;

    switch (TradeFilter())
    {
    case 1:
        OpenTrade(ORDER_TYPE_BUY);
        break;
    case -1:
        OpenTrade(ORDER_TYPE_SELL);
        break;
    }
}

//+------------------------------------------------------------------+
//| A function to test if there is a new bar                         |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime currentTime = 0;
    bool result = (currentTime != Time[0]);
    if (result)
        currentTime = Time[0];
    return (result);
}

//+------------------------------------------------------------------+
//| Function to calculate the number of bars since the last closed   |
//| trade with a specific magic number                               |
//+------------------------------------------------------------------+
int BarsSinceLastClosedTrade()
{
    datetime lastClosedTradeTime = 0;
    for (int i = 0; i < OrdersHistoryTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if (OrderMagicNumber() == TheMagicNumber && OrderType() <= OP_SELL)
            {
                lastClosedTradeTime = OrderCloseTime();
            }
        }
    }
    return (iBarShift(Symbol(), PERIOD_M30, lastClosedTradeTime, false));
}

//+------------------------------------------------------------------+
//| Function to open a trade with a delay between trades            |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType)
{
    // Check for consecutive losses and apply delay
    int consecutiveLosses = LastTradeResult(Symbol());
    if (!CheckConsecutiveLosses(consecutiveLosses))
    {
        return false;
    }

    double takeProfitPrice;
    double stopLossPrice;
    double openPrice;

    CalculateTPSL(orderType, openPrice, takeProfitPrice, stopLossPrice);

    if (OrdersTotal() == 0)
    {
        if (OrdersHistoryTotal() > 0)
        {
            LastTradeResult(Symbol());

            int ticket = OrderSend(Symbol(), orderType, Dynamic_Lots, openPrice, 0, stopLossPrice, takeProfitPrice, TradeComment, TheMagicNumber);
            if (ticket > 0)
            {
                LastTradeTime = TimeCurrent();
                return true;
            }
        }
        else
        {
            int ticket = OrderSend(Symbol(), orderType, Dynamic_Lots, openPrice, 0, stopLossPrice, takeProfitPrice, TradeComment, TheMagicNumber);
            if (ticket > 0)
            {
                LastTradeTime = TimeCurrent();
                return true;
            }
        }
    }
    return false;
}
/*
//+------------------------------------------------------------------+
//| Func to determine the market type using ADX                      |
//+------------------------------------------------------------------+
int TradeFilter()
{
   double adxSum = 0;

   for (int i = 0; i < ADXCount; i++) {
      adxSum += iADX(Symbol(), PERIOD_M30, ADXPeriod, PRICE_CLOSE, MODE_MAIN, i);
   }

   double averageAdx = adxSum / ADXCount;

   if (averageAdx >= ADXThresholdTrend) {
      return TrendingTradeFilter();
   } else if (averageAdx <= ADXThresholdRange) {
      return RangingTradeFilter();
   }

   return 0; // Return a default value or adjust as needed
}
*/
//+------------------------------------------------------------------+
//| Trade Filter Function                                            |
//| Determines whether to open a buy, sell, or no trade              |
//+------------------------------------------------------------------+
int TradeFilter()
{
    // Trending trade filter
    if (uptrend)
    {
        // Add conditions for trending buy signals
        // For example, if HH and HL points are forming, consider buying
        if (HH && HL)
        {
            // Add additional conditions as needed
            return 1; // Signal to buy
        }
    }
    else if (downtrend)
    {
        // Add conditions for trending sell signals
        // For example, if LL and LH points are forming, consider selling
        if (LL && LH)
        {
            // Add additional conditions as needed
            return -1; // Signal to sell
        }
    }

    // Add conditions for ranging trade filter if needed
    // For example, if the market is in a sideways range, implement specific buy/sell conditions

    return 0; // No trade signal
}

//+---------------------------------------------------------------------------------+
//| Function to calculate Take Profit and Stop Loss prices                          |
//+---------------------------------------------------------------------------------+
void CalculateTPSL(ENUM_ORDER_TYPE orderType, double& openPrice, double& takeprofitprice, double& stoplossprice)
{
   if (orderType == ORDER_TYPE_BUY)
   {
      openPrice = Ask;
      takeprofitprice = openPrice + TakeProfit;
      stoplossprice = Bid - StopLoss;
   }
   else
   {
      openPrice = Bid;
      takeprofitprice = openPrice - TakeProfit;
      stoplossprice = Ask + StopLoss;
   }
}

//+------------------------------------------------------------------+
//| Func for Calculating pip size                                    |
//+------------------------------------------------------------------+
double Pipsize(string symbol) {
   double point = MarketInfo(symbol, MODE_POINT);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   return( ((digits%2)==1) ? point*10 : point);
}

//+------------------------------------------------------------------+
//| Converting pips to price                                         |
//+------------------------------------------------------------------+
double PipsToPrice(double pips,string symbol) {
   return(pips*Pipsize(symbol));
}

//+------------------------------------------------------------------+
//| Martingale Function                                              |
//+------------------------------------------------------------------+

int LastTradeResult(string pair)
{
    int Last_Trade_Result = 0;
    double Last_Trade_Profit = 0;

    for (int i = 0; i < OrdersHistoryTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == TheMagicNumber)
            {
                Last_Trade_Profit = OrderProfit();
                lastTradeBar = iBarShift(NULL, 0, OrderCloseTime()); // Update lastTradeBar with the bar index of the last trade
            }
            //
            if (Last_Trade_Profit > 0)
            {
                Dynamic_Lots = Base_Lots;
                Last_Trade_Result = 1;
                consecutiveLossTrades = 0; // Reset the consecutive loss trades counter
            }
            //
            if (Last_Trade_Profit < 0)
            {
                Dynamic_Lots = OrderLots() * Lot_Step + Base_Lots;
                Last_Trade_Result = 0;
                consecutiveLossTrades++; // Increment the consecutive loss trades counter
            }
        }
        else
        {
            Print(__FUNCTION__, ", Order Select failed, error: ", GetLastError());
        }
    }
    return Last_Trade_Result;
}


//+------------------------------------------------------------------+
//| Function to check for consecutive losses and apply delay        |
//+------------------------------------------------------------------+
bool CheckConsecutiveLosses(int consecutiveLosses)
{
    if (consecutiveLosses >= Consecutiveloss)
    {
        int delayBars = Delay_Bar; // Adjust the delay as needed
        int barsSinceLastTrade = BarsSinceLastClosedTrade();
        if (barsSinceLastTrade < delayBars)
        {
            Print("Waiting for the delay before opening a new trade.");
            return false; // Wait for the delay
        }
    }
    return true;
}


//+------------------------------------------------------------------+
//| Function to identify HH, HL, LL, LH points and track trends      |
//+------------------------------------------------------------------+
void IdentifyPointsAndTrends()
{
    double prevHigh = 0.0, prevLow = 0.0;
    int lastCheckedBar = 0;

    for (int i = Bars - 2; i >= 0; i--)
    {
        if (High[i] > prevHigh && High[i] > High[i + 1] && i != lastCheckedBar)
        {
            HH[i] = true;
            HL[i] = false;
            lastCheckedBar = i;
        }
        else if (Low[i] < prevLow && Low[i] < Low[i + 1] && i != lastCheckedBar)
        {
            LL[i] = true;
            LH[i] = false;
            lastCheckedBar = i;
        }
        else
        {
            HH[i] = false;
            LL[i] = false;
        }

        if (Low[i] > prevLow && Low[i] > Low[i + 1])
        {
            LH[i] = true;
            LL[i] = false;
        }
        else if (High[i] < prevHigh && High[i] < High[i + 1])
        {
            HL[i] = true;
            HH[i] = false;
        }

        prevHigh = High[i];
        prevLow = Low[i];
    }
}


//+------------------------------------------------------------------+
//| Function to detect liquidity points and draw them on the chart   |
//+------------------------------------------------------------------+
void DetectAndDrawLiquidityPoints()
{
    for (int i = Bars - 1; i >= 0; i--)
    {
        if (HH[i])
        {
            // Draw liquidity point for HH
            ObjectCreate(0, "HH_Point_" + IntegerToString(i), OBJ_ARROW, 0, Time[i], High[i]);
            ObjectSetInteger(0, "HH_Point_" + IntegerToString(i), OBJPROP_COLOR, clrBlue);
        }
        else if (HL[i])
        {
            // Draw liquidity point for HL
            ObjectCreate(0, "HL_Point_" + IntegerToString(i), OBJ_ARROW, 0, Time[i], High[i]);
            ObjectSetInteger(0, "HL_Point_" + IntegerToString(i), OBJPROP_COLOR, clrGreen);
        }
        else if (LL[i])
        {
            // Draw liquidity point for LL
            ObjectCreate(0, "LL_Point_" + IntegerToString(i), OBJ_ARROW, 0, Time[i], Low[i]);
            ObjectSetInteger(0, "LL_Point_" + IntegerToString(i), OBJPROP_COLOR, clrRed);
        }
        else if (LH[i])
        {
            // Draw liquidity point for LH
            ObjectCreate(0, "LH_Point_" + IntegerToString(i), OBJ_ARROW, 0, Time[i], Low[i]);
            ObjectSetInteger(0, "LH_Point_" + IntegerToString(i), OBJPROP_COLOR, clrYellow);
        }
    }
}






