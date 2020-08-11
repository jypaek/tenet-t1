/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 01/06/2004
 *
 *
 *
 */


module DummySamplerM
{
  provides
  {
    interface StdControl as SamplerControl;
    interface SampleReply;
    interface SampleRequest;
  }
  uses
  {
    interface Timer;
  }
}

implementation
{
  uint8_t stop;
  
  uint8_t  m_uiSample;

#define DUMMY_MAX_SAMPLING_JOBS  10
  uint16_t samplingRate[DUMMY_MAX_SAMPLING_JOBS];
  uint16_t timeTillSample[DUMMY_MAX_SAMPLING_JOBS];
  uint8_t myChannel[DUMMY_MAX_SAMPLING_JOBS];
  uint8_t myChannelType[DUMMY_MAX_SAMPLING_JOBS];

  
  task void samplingTask( )
    {
      uint8_t i;

      if( stop == 1 )
        {
          return;
        }

      for( i = 0; (i < m_uiSample) && (i < DUMMY_MAX_SAMPLING_JOBS); i++ )
        {
          timeTillSample[i]--;
          if( timeTillSample[i] == 0 )
            {
              signal SampleReply.dataReady( i+1, myChannel[i], myChannelType[i], 1000 ) ;

              timeTillSample[i] = samplingRate[i];
            }

        }
    }
 
  event result_t Timer.fired( )
  {
    return post samplingTask( );
  }

  command result_t SamplerControl.init( )
  {
    m_uiSample = 0;
    stop = 0;

    return SUCCESS;
  }
  
  command result_t SamplerControl.start( )
  {
    stop = 0;

    call Timer.start( TIMER_REPEAT,
                      100 );

    return SUCCESS;
  }
 
  command result_t SamplerControl.stop( )
  {
    stop = 1;
    return SUCCESS;
  }
  
  command int8_t SampleRequest.getSample(uint8_t channel,uint8_t channelType,uint16_t interval,uint8_t param)
  {
    if( m_uiSample < DUMMY_MAX_SAMPLING_JOBS )
      {
        myChannel[m_uiSample] = channel;
        myChannelType[m_uiSample] = channelType;
        samplingRate[ m_uiSample ]  = interval;
        timeTillSample[ m_uiSample ]  = interval;
      }

    m_uiSample++;
    return m_uiSample;
  }
 
  command result_t SampleRequest.set_digital_output(uint8_t channel,uint8_t state)
  {
    return SUCCESS;
  }

  command result_t SampleRequest.reTask(int8_t record,uint16_t interval)
  {
    return SUCCESS;
  }

  command result_t SampleRequest.stop(int8_t record)
  {
    return SUCCESS;
  }
  
  command uint8_t SampleRequest.availableSamplingRecords( )
  {
    return 100;
  }
    
  default event result_t SampleReply.dataReady(int8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data)
  {
    return SUCCESS;
  }
}
