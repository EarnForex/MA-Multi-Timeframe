﻿#property link          "https://www.earnforex.com/metatrader-indicators/ma-multi-timeframe/"
#property version       "1.031"

#property copyright     "EarnForex.com - 2019-2023"
#property description   "This indicator will show you the status of the Moving Average indicator on multiple timeframes."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_type1 DRAW_NONE

//1.031 - Fixed non-Hull MA.

#include <MQLTA Utils.mqh> // For panel edits.

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0,  // CURRENT CANDLE
    CLOSED_CANDLE = 1    // PREVIOUS CANDLE
};

enum ENUM_MA_METHOD_EXTENDED
{
    EXT_MODE_SMA,  // Simple averaging
    EXT_MODE_EMA,  // Exponential averaging
    EXT_MODE_SMMA, // Smoothed averaging
    EXT_MODE_LWMA, // Linear-weighted averaging
    EXT_MODE_HULL  // Hull MA
};

input string Comment_1 = "====================";          // Indicator Settings
input int MAPeriod = 25;                                  // Moving Average Period
input int MAShift = 0;                                    // Moving Average Shift
input ENUM_MA_METHOD_EXTENDED MAMethod = EXT_MODE_SMA;    // Moving Average Method
input ENUM_APPLIED_PRICE MAAppliedPrice = PRICE_CLOSE;    // Moving Average Applied Price
input ENUM_CANDLE_TO_CHECK CandleToCheck = CLOSED_CANDLE; // Candle To Use For Analysis
input string Comment_2b = "===================="; // Enabled Timeframes
input bool TFM1 = true;                           // Enable Timeframe M1
input bool TFM5 = true;                           // Enable Timeframe M5
input bool TFM15 = true;                          // Enable Timeframe M15
input bool TFM30 = true;                          // Enable Timeframe M30
input bool TFH1 = true;                           // Enable Timeframe H1
input bool TFH4 = true;                           // Enable Timeframe H4
input bool TFD1 = true;                           // Enable Timeframe D1
input bool TFW1 = true;                           // Enable Timeframe W1
input bool TFMN1 = true;                          // Enable Timeframe MN1
input string Comment_3 = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = false;                       // Send Notification to Mobile
input bool SendEmail = false;                     // Send Notification via Email
input string Comment_4 = "====================";  // Graphical Objects
input bool DrawWindowEnabled = true;              // Draw Window
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel
input string IndicatorName = "MQLTA-MAMTF";       // Indicator Name (to name the objects)

double IndCurr[9], IndPrevDiff[9];

bool Positive = false;
bool Negative = false;

bool TFEnabled[9];
ENUM_TIMEFRAMES TFValues[9];
string TFText[9];
int MA_handles[9]; // Normal MA for all timeframes. In case of Hull MA, will store the p / 2 WMA handle.
int MA2_handles[9]; // Only for Hull MA - second WMA handles.

double BufferZero[1];

double LastAlertDirection = 2; // Signal that was alerted on previous alert. Double because BufferZero is double. "2" because "0", "1", and "-1" are taken for signals.

double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    CleanChart();

    TFEnabled[0] = TFM1;
    TFEnabled[1] = TFM5;
    TFEnabled[2] = TFM15;
    TFEnabled[3] = TFM30;
    TFEnabled[4] = TFH1;
    TFEnabled[5] = TFH4;
    TFEnabled[6] = TFD1;
    TFEnabled[7] = TFW1;
    TFEnabled[8] = TFMN1;
    TFValues[0] = PERIOD_M1;
    TFValues[1] = PERIOD_M5;
    TFValues[2] = PERIOD_M15;
    TFValues[3] = PERIOD_M30;
    TFValues[4] = PERIOD_H1;
    TFValues[5] = PERIOD_H4;
    TFValues[6] = PERIOD_D1;
    TFValues[7] = PERIOD_W1;
    TFValues[8] = PERIOD_MN1;
    TFText[0] = "M1";
    TFText[1] = "M5";
    TFText[2] = "M15";
    TFText[3] = "M30";
    TFText[4] = "H1";
    TFText[5] = "H4";
    TFText[6] = "D1";
    TFText[7] = "W1";
    TFText[8] = "MN1";
    Positive = false;
    Negative = false;
    
    // Prepare MA indicator handles.
    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        if (MAMethod != EXT_MODE_HULL) // Normal MAs.
        {
            MA_handles[i] = iMA(Symbol(), TFValues[i], MAPeriod, MAShift, (ENUM_MA_METHOD)MAMethod, MAAppliedPrice);
        }
        else // Hull MA.
        {
            MA_handles[i] =  iMA(Symbol(), TFValues[i], MAPeriod / 2, MAShift, MODE_LWMA, MAAppliedPrice);
            MA2_handles[i] = iMA(Symbol(), TFValues[i], MAPeriod,     MAShift, MODE_LWMA, MAAppliedPrice);
        }
    }

    SetIndexBuffer(0, BufferZero, INDICATOR_DATA);

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(40 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (PanelMovX + 1) * 3 + 2;
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    CalculateLevels();

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    CalculateLevels();

    FillBuffers();
    if (EnableNotify)
    {
        Notify();
    }

    if (DrawWindowEnabled) DrawPanel();

    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

//+------------------------------------------------------------------+
//| Processes key presses and mouse clicks.                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key pressed.
        {
            ChartIndicatorDelete(0, 0, IndicatorName);
        }
    }

    if (id == CHARTEVENT_OBJECT_CLICK) // Timeframe switching.
    {
        if (StringFind(sparam, "-P-TF-") >= 0)
        {
            string ClickDesc = ObjectGetString(0, sparam, OBJPROP_TEXT);
            ChangeChartPeriod(ClickDesc);
        }
    }
}

//+------------------------------------------------------------------+
//| Delets all chart objects created by the indicator.               |
//+------------------------------------------------------------------+
void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

//+------------------------------------------------------------------+
//| Switch chart timeframe.                                          |
//+------------------------------------------------------------------+
void ChangeChartPeriod(string Button)
{
    StringReplace(Button, "*", "");
    ENUM_TIMEFRAMES NewPeriod = 0;
    if (Button == "M1") NewPeriod = PERIOD_M1;
    if (Button == "M5") NewPeriod = PERIOD_M5;
    if (Button == "M15") NewPeriod = PERIOD_M15;
    if (Button == "M30") NewPeriod = PERIOD_M30;
    if (Button == "H1") NewPeriod = PERIOD_H1;
    if (Button == "H4") NewPeriod = PERIOD_H4;
    if (Button == "D1") NewPeriod = PERIOD_D1;
    if (Button == "W1") NewPeriod = PERIOD_W1;
    if (Button == "MN1") NewPeriod = PERIOD_MN1;
    ChartSetSymbolPeriod(0, Symbol(), NewPeriod);
}

//+------------------------------------------------------------------+
//| Main function to detect Positive, Negative, Uncertain state.     |
//+------------------------------------------------------------------+
void CalculateLevels()
{
    int EnabledCount = 0;
    int PositiveCount = 0;
    int NegativeCount = 0;
    Positive = false;
    Negative = false;
    int Shift = 0;
    if (CandleToCheck == CLOSED_CANDLE) Shift = 1;
    int MaxBars = MAPeriod + Shift + 1;
    ArrayInitialize(IndCurr, 0);
    ArrayInitialize(IndPrevDiff, 0);
    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        if (iBars(Symbol(), TFValues[i]) < MaxBars)
        {
            MaxBars = iBars(Symbol(), TFValues[i]);
            Print("Please load more historical candles. Current calculation only on ", MaxBars, " bars for timeframe ", TFText[i], ".");
            if (MaxBars < 0)
            {
                break;
            }
        }
        EnabledCount++;
        string TFDesc = TFText[i];
        double MACurrMain, MAPrevMain;
        if (MAMethod == EXT_MODE_HULL)
        {
            // Do Hull MA calculations.
            MACurrMain = iHull(i, Shift);
            MAPrevMain = iHull(i, Shift + 1);
        }
        else
        {
            double Buf[2];
            int n = CopyBuffer(MA_handles[i], 0, Shift, 2, Buf);
            if (n < 2)
            {
                Print("MA data not ready for ", Symbol(), " @ ", EnumToString(TFValues[i]));
                return;
            }
            MACurrMain = Buf[1];
            MAPrevMain = Buf[0];
        }
        double ClosePrice = iClose(Symbol(), TFValues[i], Shift);
        if ((MACurrMain == 0) || (MAPrevMain == 0))
        {
            Print("Not enough historical data, please load more candles for ", TFDesc);
        }
        if (MACurrMain < ClosePrice)
        {
            IndCurr[i] = 1;
            PositiveCount++;
        }
        if (MACurrMain > ClosePrice)
        {
            IndCurr[i] = -1;
            NegativeCount++;
        }
        if (MACurrMain > MAPrevMain)
        {
            IndPrevDiff[i] = 1;
        }
        if (MACurrMain < MAPrevMain)
        {
            IndPrevDiff[i] = -1;
        }
    }
    if (PositiveCount == EnabledCount) Positive = true;
    if (NegativeCount == EnabledCount) Negative = true;
}

//+------------------------------------------------------------------+
//| Fills indicator buffers.                                         |
//+------------------------------------------------------------------+
void FillBuffers()
{
    if (Positive) BufferZero[0] = 1;
    else if (Negative) BufferZero[0] = -1;
    else BufferZero[0] = 0;
}

//+------------------------------------------------------------------+
//| Alert processing.                                                |
//+------------------------------------------------------------------+
void Notify()
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if (LastAlertDirection == 2)
    {
        LastAlertDirection = BufferZero[0]; // Avoid initial alert when just attaching the indicator to the chart.
        return;
    }
    if (BufferZero[0] == LastAlertDirection) return; // Avoid alerting about the same signal.
    LastAlertDirection = BufferZero[0];
    string SituationString = "UNCERTAIN";
    if (Positive) SituationString = "ABOVE";
    if (Negative) SituationString = "BELOW";
    if (SendAlert)
    {
        string AlertText = "Notification: The Pair is currently - " + SituationString + ".";
        Alert(AlertText);
    }
    if (SendEmail)
    {
        string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
        string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + "\r\n";
        EmailBody += "The Pair is currently - " + SituationString + ".";
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " - The Pair is currently - " + SituationString + ".";
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelDAbove = IndicatorName + "-P-DABOVE";
string PanelDBelow = IndicatorName + "-P-DBELOW";
string PanelSig = IndicatorName + "-P-SIG";
//+------------------------------------------------------------------+
//| Main panel drawing function.                                     |
//+------------------------------------------------------------------+
void DrawPanel()
{
    string IndicatorNameTextBox = "MT MA";
    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             "Multi Time Frame Indicator",
             ALIGN_CENTER,
             "Consolas",
             IndicatorNameTextBox,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        string TFRowObj = IndicatorName + "-P-TF-" + TFText[i];
        string IndCurrObj = IndicatorName + "-P-ICURR-V-" + TFText[i];
        string IndPrevDiffObj = IndicatorName + "-P-PREVDIFF-V-" + TFText[i];
        string TFRowText = TFText[i];
        string IndCurrText = "";
        string IndPrevDiffText = "";
        string IndCurrToolTip = "";
        string IndPrevDiffToolTip = "";

        color IndCurrBackColor = clrKhaki;
        color IndCurrTextColor = clrNavy;
        color IndPrevDiffBackColor = clrKhaki;
        color IndPrevDiffTextColor = clrNavy;

        if (IndCurr[i] == 1)
        {
            IndCurrText = CharToString(225); // Up arrow.
            IndCurrToolTip = "Currently Above MA";
            IndCurrBackColor = clrDarkGreen;
            IndCurrTextColor = clrWhite;
        }
        else if (IndCurr[i] == -1)
        {
            IndCurrText = CharToString(226); // Down arrow.
            IndCurrToolTip = "Currently Below MA";
            IndCurrBackColor = clrDarkRed;
            IndCurrTextColor = clrWhite;
        }
        if (IndPrevDiff[i] == 1)
        {
            IndPrevDiffText = CharToString(225); // Up arrow.
            IndPrevDiffToolTip = "Current MA Higher than Previous Candle";
            IndPrevDiffBackColor = clrDarkGreen;
            IndPrevDiffTextColor = clrWhite;
        }
        else if (IndPrevDiff[i] == -1)
        {
            IndPrevDiffText = CharToString(226); // Down arrow.
            IndPrevDiffToolTip = "Current MA Lower than Previous Candle";
            IndPrevDiffBackColor = clrDarkRed;
            IndPrevDiffTextColor = clrWhite;
        }

        DrawEdit(TFRowObj,
                 Xoff + 2,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 8,
                 "Situation Detected in the Timeframe",
                 ALIGN_CENTER,
                 "Consolas",
                 TFRowText,
                 false,
                 clrNavy,
                 clrKhaki,
                 clrBlack);

        DrawEdit(IndCurrObj,
                 Xoff + PanelMovX + 4,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 8,
                 IndCurrToolTip,
                 ALIGN_CENTER,
                 "Wingdings",
                 IndCurrText,
                 false,
                 IndCurrTextColor,
                 IndCurrBackColor,
                 clrBlack);

        DrawEdit(IndPrevDiffObj,
                 Xoff + PanelMovX * 2 + 6,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 8,
                 IndPrevDiffToolTip,
                 ALIGN_CENTER,
                 "Wingdings",
                 IndPrevDiffText,
                 false,
                 IndPrevDiffTextColor,
                 IndPrevDiffBackColor,
                 clrBlack);

        Rows++;
    }
    string SigText = "";
    color SigColor = clrNavy;
    color SigBack = clrKhaki;
    if (Positive)
    {
        SigText = "Above";
        SigColor = clrWhite;
        SigBack = clrDarkGreen;
    }
    else if (Negative)
    {
        SigText = "Below";
        SigColor = clrWhite;
        SigBack = clrDarkRed;
    }
    else
    {
        SigText = "Uncertain";
    }

    DrawEdit(PanelSig,
             Xoff + 2,
             Yoff + (PanelMovY + 1) * Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Situation Considering All Timeframes",
             ALIGN_CENTER,
             "Consolas",
             SigText,
             false,
             SigColor,
             SigBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}

// Implements Hull moving average calculation.
double iHull(const int n, const int shift)
{
    double HMABuffer[];
    int sqrt_period = (int)MathFloor(MathSqrt(MAPeriod));
    ArrayResize(HMABuffer, sqrt_period);

    int weightsum = 0;
    double WMA = 0;

    double Buf1[], Buf2[];
    ArrayResize(Buf1, sqrt_period);
    ArrayResize(Buf2, sqrt_period);
    ArraySetAsSeries(Buf1, true);
    ArraySetAsSeries(Buf2, true);
    int count = CopyBuffer(MA_handles[n], 0, shift, sqrt_period, Buf1);
    if (count < sqrt_period)
    {
        Print("MA data not ready for ", Symbol(), " @ ", EnumToString(TFValues[n]));
        return 0;
    }
    count = CopyBuffer(MA2_handles[n], 0, shift, sqrt_period, Buf2);
    if (count < sqrt_period)
    {
        Print("MA data not ready for ", Symbol(), " @ ", EnumToString(TFValues[n]));
        return 0;
    }

    for (int i = 0; i < sqrt_period; i++)
    {
        HMABuffer[i] = 2 * Buf1[i] - Buf2[i];
        WMA += HMABuffer[i] * (sqrt_period - i);
        weightsum += (i + 1);
    }
    WMA /= weightsum;
    return WMA;
}
//+------------------------------------------------------------------+