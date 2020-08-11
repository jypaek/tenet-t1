module TransformManagerM
{
  provides
    {
      interface StdControl;
    }
  uses
    {
      interface QeAcceptDataI;
      interface SampleReply;
      interface DmMappingI;
    }
}

implementation
{
#include "StdDbg.h"
#include "sensordatatypes.h"
#include "MeasurementNames.h"
#include "SensorTypes.h"

  command result_t StdControl.init( )
    {
      return SUCCESS;
    }

  command result_t StdControl.start( )
    {
      return SUCCESS;
    }

  command result_t StdControl.stop( )
    {
      return SUCCESS;
    }

  // event void SampleReply.dataReady(uint8_t msrName, uint8_t samplingID, uint16_t sample)
  event result_t SampleReply.dataReady(int8_t samplingID, uint8_t channel, uint8_t channelType,uint16_t sample)
    {
      // Transform the data according to the measurement name.
      // Pass the samplingID and the transformed sample to the query engine.

      uint8_t msrName;
      //uint8_t msrIdx, ptIdx;
      int32_t sampleOut;
      uint8_t sensorType;
      float res;

      // Get measurement name base upon channel info.
      msrName = call DmMappingI.channelTypeNumber2mn( channelType, channel );
      sensorType = call DmMappingI.hwAddr2sensorType( channelType, channel );


      // In the case where no transform is found we just pass
      // back the data as is, so we set it here.
      sampleOut = sample;

      switch(sensorType)
        {

	case (sensor_thermister ):
	{
	  res = (float) sampleOut;

	  //sampleOut = (int)(res); works

	  // works: sampleOut = (int)(.5 + 10 * res);

	  //sampleOut = (int)(.5 + 10e-1 * (110.2149 - res));
	  // works sampleOut = (int)(.5 + 10e-1 * (110.2149 - 1.138253e-1 * res));
	  //works sampleOut = (int)(.5 + 10 * (110.2149 - (1.138253e-1) * res
	   //  + (7.509040e-5) * res * res - (3.188276e-8) * res * res * res  
	   //  ));

	  // Gives less than 0.1 degree error over -25 to 60
	   sampleOut = (int)(0.5 + 10 * (110.2149 - (1.138253e-1)*res  
	     + (7.509040e-5) *res*res - (3.188276e-8)*res*res*res  
	     + (7.069376e-12) *res*res*res*res  
	      - (6.502949e-16)*res*res*res*res*res));
          break;
	}

        case( sensor_mpxa6115a ) :
          {
            if( sample < 109 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sample <= 3906 )
              {
                sampleOut = (sample - 109);
                sampleOut *= (11651 - 1351);
                sampleOut /=  (3906 - 109);
                sampleOut += 1351;
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_windSpeedDavis ) : 
          {
            if( sample <= 500 )
              {
                sampleOut *= (1810);
                sampleOut /=  (500);
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }
          
        case( sensor_windSpeedCsMett034B ) : 
          {
            if( sample <= 629 )
              {
                sampleOut *= (1811);
                sampleOut /=  (629);
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }
          
        case( sensor_windDirectionDavis ) : 
          {
            if( sample <= 4095 )
              {
                sampleOut *= (356);
                sampleOut /=  (4095);
              }

            break;
          }
          
        case( sensor_windDirectionCsMett034B ) : 
          {
            if( sample <= 2047 )
              {
                sampleOut *= (356);
                sampleOut /=  (2047);
              }
            else if( sample <= 2100 )
              {
                sampleOut = (356);
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_echo20_2_5V ) :
          {
            if( sample < 410 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sample <= 2048 )
              {
                sampleOut -= 410;
                sampleOut *= (579 - -116);
                sampleOut /=  (2048 - 410);
                sampleOut += -116;
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_echo10_2_5V ) :
          {
            if( sample < 410 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sample <= 1802 )
              {
                sampleOut -= 410;
                sampleOut *= (653 - -142);
                sampleOut /=  (1802 - 410);
                sampleOut += -142;
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_echo20_5V ) :
          {
            if( sample < 737 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sample <= 4095 )
              {
                sampleOut -= 737;
                sampleOut *= (433 - -158);
                sampleOut /=  (4095 - 737);
                sampleOut += -158;
              }
            // No else in the spec.

            break;
          }

        case( sensor_echo10_5V ) :
          {
            if( sample < 737 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sample <= 4095 )
              {
                sampleOut -= 737;
                sampleOut *= (472 - -221);
                sampleOut /=  (4095 - 737);
                sampleOut += -221;
              }
            // No else in the spec.

            break;
          }

        // Traditionally used for outdoor
        case( sensor_parNT53373) :
        case( sensor_parNT53373_2) :
        {
          // formula: light = ((sample) * 1000000 * 2.5) / (4096 * Rc * cc)
          // cc = .65, Rc = 301
          //sampleOut *= (2500000) / (4096 * 301 * .65);
	  // --fixme-- This is all wrong, confirm this transform!!

	  if (sampleOut < 0x0830) {
	    sampleOut = 0;
	    break;
          }

	  else {
	    // Do this subtraction to account for differential channel,
	    // BUT im not even connected to diff channel. This doesn't
	    // make any sense.
	    sampleOut = (sampleOut - 0x0830) * 6.1;
	  }

	  // Got this CC value from the data-sheet
	  sampleOut *= (1000) / (301 * 12.28);
	  break;
	}

        // Par sensor used indoors, has bigger face
        case( sensor_parL11905A) :
        {
          // cc(calib coeff) = 6.11, Rc = 385
	  if (sampleOut < 0x0830) {
	    sampleOut = 0;
	    break;
          }

	  else {
	    sampleOut = (sampleOut - 0x0830) * 6.1;
	  }

	  // formula: light = (sample * 1000) / (Rc * cc);
	  sampleOut *= (1000) / (385 * 6.11);
          break;
        }

        case( sensor_parCurrent ) :
          {
            sampleOut *= (2070 - -2068);
            sampleOut /=  (4095);
            sampleOut += -2068;

            break;
          }

        case( sensor_adcVoltage ) :
          {
            sampleOut *= (2499);
            sampleOut /=  (4095);

            break;
          }

          // Inst Amp is same as thermopile.
        case( sensor_instAmpVoltage ) :
        case( sensor_thermopile ) : 
          {
            sampleOut *= (12500 - -12494);
            sampleOut /=  (4095);

            break;
          }

        case( sensor_irTemperatureMelexisMlx90601KzaBka ) : 
          {
            sampleOut *= (577 - -200);
            sampleOut /=  (4095);

            break;
          }

        case( sensor_humirelHm1500_3_3V ) :
          {
            if( sampleOut < 980 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sampleOut < 1085 )
              {
                sampleOut = UNDER_RANGE;
              }
            else if( sampleOut <= 1180 )
              {
                sampleOut = 0;
              }
            else if( sampleOut <= 1578 )
              {
                sampleOut -= 1180;
                sampleOut *= (20 - 0);
                sampleOut /=  (1578 - 1180);
              }
            else if( sampleOut <= 1891 )
              {
                sampleOut -= 1578;
                sampleOut *= (35 - 20);
                sampleOut /=  (1891 - 1578);
                sampleOut += 20;
              }
            else if( sampleOut <= 2220 )
              {
                sampleOut -= 1891;
                sampleOut *= (50 - 35);
                sampleOut /=  (2220 - 1891);
                sampleOut += 35;
              }
            else if( sampleOut <= 2569 )
              {
                sampleOut -= 2220;
                sampleOut *= (65 - 50);
                sampleOut /=  (2569 - 2220);
                sampleOut += 50;
              }
            else if( sampleOut <= 2944 )
              {
                sampleOut -= 2569;
                sampleOut *= (80 - 65);
                sampleOut /=  (2944 - 2569);
                sampleOut += 65;
              }
            else if( sampleOut <= 3213 )
              {
                sampleOut -= 2944;
                sampleOut *= (90 - 80);
                sampleOut /=  (3213 - 2944);
                sampleOut += 80;
              }
            else if( sampleOut <= 3495 )
              {
                sampleOut -= 3213;
                sampleOut *= (100 - 90);
                sampleOut /=  (3495 - 3213);
                sampleOut += 90;
              }
            else if( sampleOut <= 3645 )
              {
                sampleOut = 100;
              }
            else if( sampleOut < 3800 )
              {
                sampleOut = OVER_RANGE;
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_humirelHm1500_5V ) :
          {
            if( sampleOut < 640 )
              {
                sampleOut = LOW_FAULT;
              }
            else if( sampleOut < 740 )
              {
                sampleOut = UNDER_RANGE;
              }
            else if( sampleOut <= 840 )
              {
                sampleOut = 0;
              }
            else if( sampleOut <= 1311 )
              {
                sampleOut -= 840;
                sampleOut *= (20 - 0);
                sampleOut /=  (1311 - 840);
              }
            else if( sampleOut <= 1630 )
              {
                sampleOut -= 1311;
                sampleOut *= (35 - 20);
                sampleOut /=  (1630 - 1311);
                sampleOut += 20;
              }
            else if( sampleOut <= 1933 )
              {
                sampleOut -= 1630;
                sampleOut *= (50 - 35);
                sampleOut /=  (1933 - 1630);
                sampleOut += 35;
              }
            else if( sampleOut <= 2236 )
              {
                sampleOut -= 1933;
                sampleOut *= (65 - 50);
                sampleOut /=  (2236 - 1933);
                sampleOut += 50;
              }
            else if( sampleOut <= 2560 )
              {
                sampleOut -= 2236;
                sampleOut *= (80 - 65);
                sampleOut /=  (2560 - 2236);
                sampleOut += 65;
              }
            else if( sampleOut <= 2789 )
              {
                sampleOut -= 2560;
                sampleOut *= (90 - 80);
                sampleOut /=  (2789 - 2560);
                sampleOut += 80;
              }
            else if( sampleOut <= 3045 )
              {
                sampleOut -= 2789;
                sampleOut *= (100 - 90);
                sampleOut /=  (3045 - 2789);
                sampleOut += 90;
              }
            else if( sampleOut <= 3180 )
              {
                sampleOut = 100;
              }
            else if( sampleOut < 3333 )
              {
                sampleOut = OVER_RANGE;
              }
            else
              {
                sampleOut = HIGH_FAULT;
              }

            break;
          }

        case( sensor_temperatureBcThermistor ) :
          {
            if( sampleOut < 486 )
              {
                sampleOut = HIGH_FAULT;
              }
            else if( sampleOut <= 658 )
              {
                sampleOut -= 486;
                sampleOut *= (600 - 700);
                sampleOut /=  (658 - 486);
                sampleOut += 700;
              }
            else if( sampleOut <= 765 )
              {
                sampleOut -= 658;
                sampleOut *= (600 - 550);
                sampleOut /=  (765 - 658);
                sampleOut += 600;
              }
            else if( sampleOut <= 889 )
              {
                sampleOut -= 765;
                sampleOut *= (500 - 550);
                sampleOut /=  (889 - 765);
                sampleOut += 550;
              }
            else if( sampleOut <= 1030 )
              {
                sampleOut -= 889;
                sampleOut *= (450 - 500);
                sampleOut /=  (1030 - 889);
                sampleOut += 500;
              }
            else if( sampleOut <= 1191 )
              {
                sampleOut -= 1030;
                sampleOut *= (400 - 450);
                sampleOut /=  (1191 - 1030);
                sampleOut += 450;
              }
            else if( sampleOut <= 1370 )
              {
                sampleOut -= 1191;
                sampleOut *= (350 - 400);
                sampleOut /=  (1370 - 1191);
                sampleOut += 400;
              }
            else if( sampleOut <= 1567 )
              {
                sampleOut -= 1370;
                sampleOut *= (300 - 350);
                sampleOut /=  (1567 - 1370);
                sampleOut += 350;
              }
            else if( sampleOut <= 1780 )
              {
                sampleOut -= 1567;
                sampleOut *= (250 - 300);
                sampleOut /=  (1780 - 1567);
                sampleOut += 300;
              }
            else if( sampleOut <= 2007 )
              {
                sampleOut -= 1780;
                sampleOut *= (200 - 250);
                sampleOut /=  (2007 - 1780);
                sampleOut += 250;
              }
            else if( sampleOut <= 2662 )
              {
                sampleOut -= 2007;
                sampleOut *= (60 - 200);
                sampleOut /=  (2662 - 2007);
                sampleOut += 200;
              }
            else if( sampleOut <= 2927 )
              {
                sampleOut -= 2662;
                sampleOut *= (0 - 60);
                sampleOut /=  (2927 - 2662);
                sampleOut += 60;
              }
            else if( sampleOut <= 3130 )
              {
                sampleOut -= 2927;
                sampleOut *= (-50 - 0);
                sampleOut /=  (3130 - 2927);
                sampleOut += 0;
              }
            else if( sampleOut <= 3313 )
              {
                sampleOut -= 3130;
                sampleOut *= (-100 - -50);
                sampleOut /=  (3313 - 3130);
                sampleOut += -50;
              }
            else if( sampleOut <= 3473 )
              {
                sampleOut -= 3313;
                sampleOut *= (-150 - -100);
                sampleOut /=  (3473 - 3313);
                sampleOut += -100;
              }
            else if( sampleOut <= 3609 )
              {
                sampleOut -= 3473;
                sampleOut *= (-200 - -150);
                sampleOut /=  (3609 - 3473);
                sampleOut += -150;
              }
            else if( sampleOut <= 3741 )
              {
                sampleOut -= 3609;
                sampleOut *= (-260 - -200);
                sampleOut /=  (3741 - 3609);
                sampleOut += -200;
              }
            else 
              {
                sampleOut = LOW_FAULT;
              }

            break;
          }

        case( sensor_leafWetnessDavis ) :
          {
            if( sampleOut <= 836 )
              {
                sampleOut = 10;
              }
            else if( sampleOut <= 2720 )
              {
                sampleOut -= 836;
                sampleOut *= (0 - 10);
                sampleOut /=  (2720 - 836);
                sampleOut += 10;
              }
            else
              {
                sampleOut = 0;
              }

            break;
          }

        case( sensor_rainGaugeDavis ) :
          {
            // Does nothing.
            break;
          }
        }


      call QeAcceptDataI.passData( (int16_t)(sampleOut), samplingID );

      return SUCCESS;
    }
}
