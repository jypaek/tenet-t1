includes QueryTypes;
includes MeasurementNames;

module QueryEngineM {
  provides {
      interface QeAcceptQueryI;
      interface QeAcceptDataI;
    }
  uses {
#ifdef NOISE_WINDOW
      interface Timer;
#endif
      interface DmAcceptMnAndTI;
      interface ChAcceptCmdI;
      interface QueryTableI;
      interface Leds;
#ifdef SYMPATHY_DSE
      interface ProvideCompMetrics;
#endif

#ifdef NODE_HEALTH
      interface NodeHealthI;
#endif
    }
}

implementation
{
#include "StdDbg.h"
#include "QueryConstants.h"
#include "ConfigConst.h"
#ifdef NODE_HEALTH
#include "NodeHealth.h"
#endif  

  // Prototypes
  result_t ConfigCommand(uint8_t *query);
  result_t DeleteQuery(QueryHeader_t *queryHeader);
  result_t SingleQuery(QueryHeader_t *queryHeader);
  result_t PeriodicQuery(QueryHeader_t *queryHeader);
  result_t PeriodicConditionalQuery(QueryHeader_t *queryHeader);
  result_t EventQuery(QueryHeader_t *queryHeader);
  result_t EventAggregateQuery(QueryHeader_t *queryHeader);

  result_t SingleData(QueryHeader_t *qtHeaderPtr,
                      uint16_t sample, uint8_t samplingID);
  result_t PeriodicData(QueryHeader_t *qtHeaderPtr,
                        uint16_t sample, uint8_t samplingID);
  result_t PeriodicConditionalData(QueryHeader_t *qtHeaderPtr,
                                   uint16_t sample, uint8_t samplingID);
  result_t EventData(QueryHeader_t *qtHeaderPtr,
                     uint16_t sample, uint8_t samplingID);
  result_t EventAggregateData(QueryHeader_t *qtHeaderPtr,
                              uint16_t sample, uint8_t samplingID);

  void cancel_all_sampling_jobs(QueryState_t *qtStatePtr);
  void cancel_sampling_jobs(QueryState_t *qtStatePtr,
                            uint8_t start_index, uint8_t stop_index);
  uint16_t set_available_mns(QueryHeader_t *queryHeader);
  result_t mn_set(QueryHeader_t *qtHeaderPtr, uint8_t i);
  QueryHeader_t *insert_query(QueryHeader_t *queryHeader, uint16_t bitMask);

  result_t start_sampling_all(QueryHeader_t *qtHeaderPtr);
  result_t start_sampling_first(QueryHeader_t *qtHeaderPtr);
  result_t start_sampling_rest(QueryHeader_t *qtHeaderPtr);

  QueryData_t *store_data(QueryHeader_t *qtHeaderPtr,
                          uint16_t sample, uint8_t samplingID);
  QueryHeader_t *get_query(uint8_t samplingID);
  void send_data(QueryHeader_t *qtHeaderPtr,
                 QueryData_t *qtDataPtr, uint8_t qRespDataLen);
  result_t valid_sampling_id(uint8_t samplingID);
  bool all_samples_received(QueryHeader_t *qtHeaderPtr);
  bool time_to_send(QueryHeader_t *qtHeaderPtr);

#ifdef SYMPATHY_DSE
  Sympathy_comp_stats_t stats = {};
#endif

#ifdef NOISE_WINDOW
  // If 0, then no noise-window samples are requested
  uint8_t nw_queryID = 0;
  uint8_t nw_maxEpoch = 0;
  uint8_t nw_noiseWindow = 0;
  uint8_t nw_mns[MAX_MNS + 1];
  uint8_t num_samples = 0; /* need NUMBER_SAMPLES_PER_NOISE_WINDOW samples for
  			   * each noise window */

  // Determines if we are sampling, and what the current mn we are sampling
  uint8_t nw_sampling = 0;
#endif

#if defined(PLATFORM_PC) || defined(PLATFORM_EMSTAR)
  void print_query_header(long long level, char *file,
                          uint32_t line,
                          QueryHeader_t *queryHeader);
#else
#define print_query_header(...) { }
#endif

#ifdef SYMPATHY_DSE
  event result_t ProvideCompMetrics.exposeSymStats(Sympathy_comp_stats_t *data, uint8_t *len) {
    memcpy(data, &stats, sizeof(stats));
    *len = sizeof(stats);
    return SUCCESS;
  }
  event result_t ProvideCompMetrics.exposeGenericStats(uint8_t *data, uint8_t *len) { return FAIL; }
#endif

#ifdef NODE_HEALTH
// how many active queries this node currently has
// need to know when to enable / disable health checking
static int query_count = 0;
// maximum time between which this module 
// should be active.  Don't want to risk rebooting the node when the 
// query with the minimum sampling time is delted
static uint16_t maximum_sampling_period = 0;
#endif

  uint8_t oneCnt(uint16_t mask){
    uint8_t cnt, i;
    uint16_t bit;

    cnt = 0;
    bit = 1;
    for( i = 0; i < 16; i++ ) {
      if( (mask & bit) > 0 ) {
        cnt++;
      }
      bit <<= 1;
    }
    return cnt;
  }

  void flipBit( uint16_t* masterMaskPtr, uint16_t* slaveMaskPtr, uint8_t idx ){
    uint8_t cnt, i;
    uint16_t bit;

    cnt = 0;
    bit = 1;
    for( i = 0; i < 16; i++ ){
      if( ((*masterMaskPtr) & bit) > 0 ){
        if( cnt == idx ){
          (*slaveMaskPtr) |= bit;
          return;
        }
        cnt++;
      }
      bit <<= 1;
    }
    return;
  }

#ifdef NOISE_WINDOW

  void set_noise_window(QueryHeader_t* qh) {

    // Increment query-id so that each sensor has a unique queryID.
    // The server knows that this will happen
    // HOWEVER: that means that users cannot use the queryID close to these!
    qh->queryID = nw_queryID + nw_sampling;
    qh->mn[0] = nw_mns[nw_sampling];

//    qh->noiseWindow = NUMBER_SAMPLES_PER_NOISE_WINDOW;
//    qh->maxEpoch = NOISE_WINDOW_SAMPLES;
    qh->noiseWindow = nw_noiseWindow;
    qh->maxEpoch = nw_maxEpoch;

    // If sensor is battery, then we only want 1 sample in the noise-window
    if (qh->mn[0] == moteBattery) {
      qh->noiseWindow = 1;
      qh->maxEpoch = 1;
    }
  }

  result_t nw_delete_query() {
    QueryHeader_t queryHeader = {
      queryFlags: delete_query,
    };
    result_t ret;

    // Reset the number of samples taken for the current sensor
    num_samples = 0;

    // The correct queryID is nw_queryID + nw_sampling - 1 because nw_sampling
    // has been incremented
    queryHeader.queryID = nw_queryID + nw_sampling - 1;
    ret = call QeAcceptQueryI.passQuery((uint8_t *)&queryHeader);
    return ret;
  }
  
  // If a specific sensor-type query fails, send the next one
  result_t nw_insert_query() {
    uint8_t buf[sizeof(QueryHeader_t) + 10];
    QueryHeader_t* queryHeader = (QueryHeader_t *)buf;
    result_t ret = FAIL;

    memset(buf, 0, sizeof(buf));
    queryHeader->queryFlags = periodic_sample;
    queryHeader->samplingPeriod = NOISE_WINDOW_PERIOD;
    queryHeader->mnCnt = 1;
    
    // Finished sampling all sensors. Check for MAX_MNS because
    // nw_delete_query just incremented nw_sampling.
    if (nw_sampling >= MAX_MNS) goto reset_sampling;

    // Try to find a non-0 sensor to sample. We can't skip this step
    // because although the first mn must be non-0, subsequent mns may
    // be 0, so we check to see if we have already submitted the last sensor
    while ( ((queryHeader->mn[0] = nw_mns[nw_sampling]) == 0)
    	&& (nw_sampling < MAX_MNS-1)) {
	nw_sampling++;
    }
//    call Leds.redToggle();

    // If none exist, then don't submit any queries, and reset nw_sampling 
    // Here we check for nw_sampling >= MAX_MNS - 1 because nw_sampling
    // is not valid at MAX_MNS, so we won't increment it that far in the 
    // above while loop
    if (nw_sampling >= MAX_MNS - 1) goto reset_sampling;

    set_noise_window(queryHeader);

    while ( ((ret = call QeAcceptQueryI.passQuery((uint8_t *)queryHeader)) == FAIL) 
    	&& (nw_sampling < MAX_MNS - 1)) {
      // If pass-query fails, try to find a sensor-type that succeeds
      nw_sampling++;
      set_noise_window(queryHeader);
    }
//    call Leds.greenToggle();

    if (ret == SUCCESS) {
      // Increment nw_sampling to get the next sensor
      nw_sampling++;
      return ret;
    }

    // If we couldn't insert the query, then just reset nw_sampling
    // And try again next period
reset_sampling:
//    call Leds.yellowToggle();
    nw_sampling = 0;
    return ret;
  }

  // Only send the first successful sensor query because we can only
  // sample one sensor at a time
  event result_t Timer.fired() {
//    call Leds.greenToggle();
    if (nw_sampling) return SUCCESS;
    nw_insert_query();
    return SUCCESS;
  }
#endif

  command result_t QeAcceptQueryI.passQuery(uint8_t* query) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.

    QueryHeader_t* queryHeader;
    result_t ret = SUCCESS;
    uint8_t queryType;

    queryHeader = (QueryHeader_t*)query;
    queryType = QUERY_TYPE(queryHeader);

    // We count the query as having been received, even if ret==FAIL
    // This is so that the user can try to deduce that the queries are
    // being received, they are just not being fulfilled!
#ifdef SYMPATHY_DSE
    stats.num_pkts_rx++;
#endif

#ifdef NOISE_WINDOW
    // If we are doing noise window sampling, then don't submit a query
    // via the traditional route
    if (IS_NOISE_WINDOW_SAMPLING(queryHeader) 
    	&& ( (queryType == periodic_sample)
    	     || (queryType == single_sample))) {
      nw_queryID = queryHeader->queryID;
      nw_maxEpoch = queryHeader->maxEpoch;
      nw_noiseWindow = queryHeader->noiseWindow;

      // If either is 0, set to the default
      if (nw_maxEpoch == 0) {
        nw_maxEpoch = NOISE_WINDOW_SAMPLES;
      }
      if (nw_noiseWindow == 0) {
        nw_noiseWindow = NUMBER_SAMPLES_PER_NOISE_WINDOW;
      }
     
      memset(nw_mns, 0, MAX_MNS * sizeof(uint8_t));
      memcpy(nw_mns, queryHeader->mn, queryHeader->mnCnt);

      // Disable previous noise-window sample
      call Timer.stop();

      // If we are in middle of a sample, delete it
      if (nw_sampling) {
        nw_delete_query();
        nw_sampling = 0;
      }
      {
        uint32_t time = (uint32_t) queryHeader->samplingPeriod * (uint32_t)100;
        call Timer.start(TIMER_REPEAT, time);
      }

      // Start a query cycle now
      nw_insert_query();
      return SUCCESS;
    }
#endif

    switch(queryType) {
    case delete_query:
      ret =  DeleteQuery(queryHeader);
      break;
    case single_sample:
      ret =  SingleQuery(queryHeader);
      break;
    case periodic_sample:
      ret =  PeriodicQuery(queryHeader);
      break;
    case periodic_conditional_sample:
      ret =  PeriodicConditionalQuery(queryHeader);
      break;
    case event_sample:
      ret =  EventQuery(queryHeader);
      break;
    case event_aggregate_sample:
      ret =  EventAggregateQuery(queryHeader);
      break;
    case config_command:
      ret =  ConfigCommand(query);
      break;
    default:
      dbg(DBG_ERROR, "Unknown query type: %d\n", QUERY_TYPE(queryHeader));
      ret = FAIL;
    }

    // if ret == SUCCESS we know that our available sensors can fulfill
    // the data requirements, that we have enough memory to
    // store the data, and that we have the sampling IDs stored.  Now it
    // is time to let the sampler do its job.
    return ret;
  }

  command result_t QeAcceptDataI.passData(uint16_t sample, uint8_t samplingID){
    QueryHeader_t* qtHeaderPtr;
    result_t ret = SUCCESS;

    if ((qtHeaderPtr = get_query(samplingID)) == NULL) return FAIL;

#ifdef NODE_HEALTH
    call NodeHealthI.ActionStart(DATA_GENERATION);
#endif

    switch( QUERY_TYPE(qtHeaderPtr) ){
    case single_sample:
      ret =  SingleData(qtHeaderPtr, sample, samplingID);
      break;
    case periodic_sample:
      ret =  PeriodicData(qtHeaderPtr, sample, samplingID);
      break;
    case periodic_conditional_sample:
      ret =  PeriodicConditionalData(qtHeaderPtr, sample, samplingID);
      break;
    case event_sample:
      ret =  EventData(qtHeaderPtr, sample, samplingID);
      break;
    case event_aggregate_sample:
      ret =  EventAggregateData(qtHeaderPtr, sample, samplingID);
      break;
    default:
      dbg(DBG_ERROR, "can't find query type\n");
      ret =  FAIL;
    }

#ifdef NODE_HEALTH
    call NodeHealthI.ActionEnd(DATA_GENERATION);
#endif

    return ret;
  }

  result_t DeleteQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    QueryHeader_t* qtHeaderPtr;
    QueryState_t* qtStatePtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    // Retrieve query based upon ID.

    if ((qtHeaderPtr = (QueryHeader_t *)
         call QueryTableI.requestByID(queryHeader->queryID)) == NULL){
      dbg(DBG_ERROR, "query id %d not found in query table\n",
          queryHeader->queryID);
      return FAIL;
    }

    qtStatePtr = QUERY_STATE(qtHeaderPtr);

#ifdef NODE_HEALTH
    if (query_count <= 1)
    {
        // deleting last active query - disable node health checking
        call NodeHealthI.Enable(DATA_GENERATION, DISABLE); 
        maximum_sampling_period = 0;
    }
    query_count = query_count - 1;

     dbg(DBG_ERROR, "Deleting query: currently %d remaining\n", query_count);  
#endif    

    // Cancel all sampling jobs.
    cancel_all_sampling_jobs(qtStatePtr);

    // Free query storage.
    call QueryTableI.deleteQueryID( qtHeaderPtr->queryID );


   

    return SUCCESS;
  }

  result_t SingleQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    uint16_t bitMask;

    QueryHeader_t* qtHeaderPtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    if ((bitMask = set_available_mns(queryHeader)) == 0)
      return FAIL;

    if ((qtHeaderPtr = insert_query(queryHeader, bitMask)) == NULL)
      return FAIL;

    if (start_sampling_all(qtHeaderPtr) == FAIL)
      return FAIL;

    return SUCCESS;
  }

  result_t PeriodicQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    uint16_t bitMask;

    QueryHeader_t* qtHeaderPtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    if ((bitMask = set_available_mns(queryHeader)) == 0)
      return FAIL;

    if ((qtHeaderPtr = insert_query(queryHeader, bitMask)) == NULL)
      return FAIL;

    if (start_sampling_all(qtHeaderPtr) == FAIL)
      return FAIL;

#ifdef NODE_HEALTH
    if (queryHeader->samplingPeriod > maximum_sampling_period)
    {
        maximum_sampling_period = queryHeader->samplingPeriod;
        call NodeHealthI.SetParameters(DATA_GENERATION, 
                                       DEFAULT_PROCESSING_TIME,
                                       maximum_sampling_period,
                                       FLAG_RESERVED);
    }

    if (query_count == 0)
    {
        // adding a query when we didn't have one before
        // enable node health checking
        call NodeHealthI.Enable(DATA_GENERATION, ENABLE); 
    }

    query_count += 1;

    dbg(DBG_ERROR, "Adding query: currently %d remaining\n", query_count);
#endif    


    return SUCCESS;
  }

  result_t PeriodicConditionalQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    uint16_t bitMask;

    QueryHeader_t* qtHeaderPtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    if ((bitMask = set_available_mns(queryHeader)) == 0) return FAIL;

    // Is the first measurement name set?
    // If it is missing then the queryHeader cannot be executed.
    if(  mn_set(queryHeader, 0) == FAIL ){
      return FAIL;
    }

    if ((qtHeaderPtr = insert_query(queryHeader, bitMask)) == NULL)
      return FAIL;

    if (start_sampling_all(qtHeaderPtr) == FAIL)
      return FAIL;

    return SUCCESS;
  }

  result_t EventQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    uint16_t bitMask;

    QueryHeader_t* qtHeaderPtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    if ((bitMask = set_available_mns(queryHeader)) == 0) return FAIL;

    // Is the first measurement name set?
    // If it is missing then the queryHeader cannot be executed.
    if(  mn_set(queryHeader, 0) == FAIL )
      return FAIL;

    if ((qtHeaderPtr = insert_query(queryHeader, bitMask)) == NULL)
      return FAIL;

    if (start_sampling_first(qtHeaderPtr) == FAIL)
      return FAIL;

    return SUCCESS;
  }

  result_t EventAggregateQuery(QueryHeader_t *queryHeader) {
    // Ask datamap if the measurement names are available.
    // Depending on MN availability and whether exact match is
    // specified, either ask query table to store it.
    uint16_t bitMask;

    QueryHeader_t* qtHeaderPtr;

    print_query_header(DBG_USR3, __FILE__, __LINE__, queryHeader);

    if ((bitMask = set_available_mns(queryHeader)) == 0) return FAIL;

    // Is the first measurement name set?
    // If it is missing then the queryHeader cannot be executed.
    if(  mn_set(queryHeader, 0) == FAIL )
      return FAIL;

    if ((qtHeaderPtr = insert_query(queryHeader, bitMask)) == NULL)
      return FAIL;

    if (start_sampling_first(qtHeaderPtr) == FAIL)
      return FAIL;

    return SUCCESS;
  }

  result_t SingleData(QueryHeader_t *qtHeaderPtr, uint16_t sample, uint8_t samplingID) {
    // Ask the queryHeader table to return the queryHeader that possesses the
    // sampling ID.
    // Parse the query, store the data at the appropriate spot.
    // If the queryHeader can be evalutated, do so.
    // If a result can be sent to the user, do so.
    QueryState_t* qtStatePtr;
    QueryData_t* qtDataPtr;
    uint8_t maxI;

    uint8_t qRespDataLen = 0;

    if (valid_sampling_id(samplingID) == FAIL) return FAIL;

    if ((qtDataPtr = store_data(qtHeaderPtr, sample, samplingID)) == NULL)
      return FAIL;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // At this point the data has been stored.  Now it is time to check
    // what other sort of processing is needed.

    if (all_samples_received(qtHeaderPtr)){
      // Increment epoch counter.
      qtStatePtr->curEpoch++;

      if (time_to_send(qtHeaderPtr)){
        // Pack it up and send it.
        qRespDataLen = (qtHeaderPtr->maxEpoch) * maxI;

        send_data(qtHeaderPtr, qtDataPtr, qRespDataLen);

        // For 'single samples' we need to get rid of
        // the sampling IDs and cancel the query.
        stddbg1( "Killing sampling jobs for single sample." );

        // Need to cancel all samling jobs.
        cancel_sampling_jobs(qtStatePtr, 0, maxI);

        // Erase Query
        call QueryTableI.deleteQueryID( qtHeaderPtr->queryID );

      }
    }

    return SUCCESS;
  }

  result_t PeriodicData(QueryHeader_t *qtHeaderPtr, uint16_t sample, uint8_t samplingID) {
    // Ask the queryHeader table to return the queryHeader that possesses the
    // sampling ID.
    // Parse the query, store the data at the appropriate spot.
    // If the queryHeader can be evalutated, do so.
    // If a result can be sent to the user, do so.
    QueryState_t* qtStatePtr;
    QueryData_t* qtDataPtr;
    uint8_t maxI;

    uint8_t qRespDataLen = 0;

    if (valid_sampling_id(samplingID) == FAIL) return FAIL;

    if ((qtDataPtr = store_data(qtHeaderPtr, sample, samplingID)) == NULL)
      return FAIL;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // At this point the data has been stored.  Now it is time to check
    // what other sort of processing is needed.

    if (all_samples_received(qtHeaderPtr)){
      qtStatePtr->curEpoch++;

      if (time_to_send(qtHeaderPtr)){
        // Pack it up and send it.
        qRespDataLen = (qtHeaderPtr->maxEpoch) * maxI;

        //dbg(DBG_ERROR, "Sending data %d\n", qtDataPtr->data[0]);

        //call Leds.set(0x3 & maxI);
        send_data(qtHeaderPtr, qtDataPtr, qRespDataLen);

       // If we are doing noise-window sampling for this query, delete curr query
       // And see if we have more sensors to sample
       // NR Check if IS_NOISE_WINDOW_SAMPLING, because node may be processing
       // other queries that are not noise-window sampling queries, and that is
       // what may have just completed
#ifdef NOISE_WINDOW
        print_query_header(DBG_USR3, __FILE__, __LINE__, qtHeaderPtr);
	num_samples += qtHeaderPtr->maxEpoch;
        if ((nw_sampling) && (num_samples >= qtHeaderPtr->noiseWindow)) {
          nw_delete_query();
          nw_insert_query();
	}
#endif
      }
    }

    return SUCCESS;
  }

  result_t PeriodicConditionalData(QueryHeader_t *qtHeaderPtr, uint16_t sample, uint8_t samplingID) {
    // Ask the queryHeader table to return the queryHeader that possesses the
    // sampling ID.
    // Parse the query, store the data at the appropriate spot.
    // If the queryHeader can be evalutated, do so.
    // If a result can be sent to the user, do so.
    QueryState_t* qtStatePtr;
    QueryData_t* qtDataPtr;
    uint8_t maxI;
    uint16_t val;

    uint8_t qRespDataLen = 0;

    if (valid_sampling_id(samplingID) == FAIL) return FAIL;

    if ((qtDataPtr = store_data(qtHeaderPtr, sample, samplingID)) == NULL)
      return FAIL;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // At this point the data has been stored.  Now it is time to check
    // what other sort of processing is needed.

    if (all_samples_received(qtHeaderPtr)){
      // Check to see if sample for the first MN
      // satisfies the sampling condition.
      // If not, erase the data from this epoch.
      // If so, increment the epoch counter.
      val = (qtDataPtr->data)[ (qtStatePtr->curEpoch)*maxI ];
      stddbg( "Conditional query:  val = %d, reading = %d", val, qtHeaderPtr->compVal );
      if( IS_COMP_OPER(qtHeaderPtr) ) {
        if( val < qtHeaderPtr->compVal ) {
          stddbg1( "Less than condition satisfied." );
          // Increment epoch counter.
          qtStatePtr->curEpoch++;
        }
        else {
          stddbg1( "Less than condition NOT satisfied." );
        }
      }
      else {
        if( val > qtHeaderPtr->compVal ) {
          stddbg1( "Greater than than condition satisfied." );
          // Increment epoch counter.
          qtStatePtr->curEpoch++;
        }
        else {
          stddbg1( "Greater than than condition NOT satisfied." );
        }
      }

      // If the comparison is not satisfied then
      // we don't update the epoch.  In this case
      // the data that comes after this point will
      // over-write this data.

      if (time_to_send(qtHeaderPtr)){
        // Pack it up and send it.
        qRespDataLen = (qtHeaderPtr->maxEpoch) * maxI;
        send_data(qtHeaderPtr, qtDataPtr, qRespDataLen);
      }
    }

    return SUCCESS;
  }

  result_t EventData(QueryHeader_t *qtHeaderPtr, uint16_t sample, uint8_t samplingID) {
    // Ask the queryHeader table to return the queryHeader that possesses the
    // sampling ID.
    // Parse the query, store the data at the appropriate spot.
    // If the queryHeader can be evalutated, do so.
    // If a result can be sent to the user, do so.
    QueryState_t* qtStatePtr;
    QueryData_t* qtDataPtr;
    uint8_t maxI;

    uint8_t qRespDataLen = 0;

    if (valid_sampling_id(samplingID) == FAIL) return FAIL;

    if ((qtDataPtr = store_data(qtHeaderPtr, sample, samplingID)) == NULL)
      return FAIL;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // At this point the data has been stored.  Now it is time to check
    // what other sort of processing is needed.

    if (all_samples_received(qtHeaderPtr)){

      // event_sample and event_aggregate sample are
      // handled equivalenty up until the point where
      // the queries are evaluated.  The aggregate
      // then requires more processing (see below).

      stddbg1( "Data collected for event.  Cancelling sampling jobs" );

      // Need to cancel all sampling jobs.
      // Because we don't want to stop the event-based
      // trigger, we start with iter at 1.
      cancel_sampling_jobs(qtStatePtr,1,maxI);

      // Increment epoch counter.
      qtStatePtr->curEpoch++;

      if (time_to_send(qtHeaderPtr)){
        // Pack it up and send it.
        // Sensor data is 2 bytes per entry
        qRespDataLen = (qtHeaderPtr->maxEpoch) * maxI;
        // Kill sampling IDs.
        // NEED TO START FROM 1 so that event sensor keeps going.
        cancel_sampling_jobs(qtStatePtr, 1, maxI);

        send_data(qtHeaderPtr, qtDataPtr, qRespDataLen);

      }  // if time_to_send()
    } // if all_samples_received()
    else {
      // Issue request to sample analog sensors.
      if (start_sampling_rest(qtHeaderPtr) == FAIL) return FAIL;
    }

    return SUCCESS;
  }

  result_t EventAggregateData(QueryHeader_t *qtHeaderPtr, uint16_t sample, uint8_t samplingID) {
    // Ask the queryHeader table to return the queryHeader that possesses the
    // sampling ID.
    // Parse the query, store the data at the appropriate spot.
    // If the queryHeader can be evalutated, do so.
    // If a result can be sent to the user, do so.
    QueryState_t* qtStatePtr;
    QueryData_t* qtDataPtr;
    uint8_t maxI;
    uint8_t iter, iter2;
    uint32_t agg;

    uint8_t qRespDataLen = 0;

    if (valid_sampling_id(samplingID) == FAIL) return FAIL;

    if ((qtDataPtr = store_data(qtHeaderPtr, sample, samplingID)) == NULL)
      return FAIL;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // At this point the data has been stored.  Now it is time to check
    // what other sort of processing is needed.

    if (all_samples_received(qtHeaderPtr)){
      // event_sample and event_aggregate sample are
      // handled equivalenty up until the point where
      // the queries are evaluated.  The aggregate
      // then requires more processing (see below).

      stddbg1( "Data collected for event.  Cancelling sampling jobs" );

      // Need to cancel all sampling jobs.
      // Because we don't want to stop the event-based
      // trigger, we start with iter at 1.
      cancel_sampling_jobs(qtStatePtr,1,maxI);

      // Increment epoch counter.
      qtStatePtr->curEpoch++;

      if (time_to_send(qtHeaderPtr)){
        // Pack it up and send it.
        // Here, we also need queryHeader specific handling.

        // Perform aggreagtion.
        if( IS_MIN_AGG_FUNC(qtHeaderPtr) ) {
          for( iter = 0; iter < maxI; iter++ ) {
            agg = 0;
            qRespDataLen = qtHeaderPtr->maxEpoch;
            for( iter2 = 0; iter2 < qRespDataLen; iter2++ ) {
              agg += (qtDataPtr->data)[ iter2*maxI + iter ];
            }
            agg /= qtHeaderPtr->maxEpoch;

            //(qResp->data)[iter] = (uint16_t)(agg);
            qtDataPtr->data[ iter ] = agg;
          }
        }
        else { // AGG_FUNC == MAX
          for( iter = 0; iter < maxI; iter++ ){
            //max = 0;
            qRespDataLen = qtHeaderPtr->maxEpoch;

            // Start from 1 since we can assume that
            // the 0 data point is the max so far.
            for( iter2 = 1; iter2 < qRespDataLen; iter2++ ){
              if( (qtDataPtr->data)[ iter2*maxI + iter ]
                  > (qtDataPtr->data)[ iter ] ) {
                (qtDataPtr->data)[ iter ]
                  = (qtDataPtr->data)[ iter2*maxI + iter ];
              }
            }

            //(qResp->data)[iter] = max;
          }
        }
        // Kill sampling IDs.
        // NEED TO START FROM 1 SO THAT EVENT KEEPS FIRING.
        cancel_sampling_jobs(qtStatePtr, 1, maxI);

        send_data(qtHeaderPtr, qtDataPtr, qRespDataLen);

      } // if time_to_send()
    } // if all_samples_received()
    else {
      // Issue request to sample analog sensors.
      if (start_sampling_rest(qtHeaderPtr) == FAIL) return FAIL;
    }

    return SUCCESS;
  }


  uint8_t configFlag;
  uint8_t configQueryId;

  result_t ConfigCommand(uint8_t* query)
    {
      // Ask datamap if the measurement names are available.
      // Depending on MN availability and whether exact match is
      // specified, either ask query table to store it.
      ConfigCommandHeader_t* cch = (ConfigCommandHeader_t*)query;
      
      /*
      char buff[1024];
      char buff2[100];
      int i;

      buff[0] = '\0';
      
      dbg(DBG_USR3, "Got config command.  Raw:\n");

      for( i = 0; i < sizeof(ConfigCommandHeader_t); i++ )
        {
          sprintf(buff2, "%x ", ((uint8_t*)(query))[i]);
          strcat(buff, buff2);
        }

      dbg(DBG_USR3, "%s\n", buff);


      buff[0] = '\0';

      sprintf(buff2, "cmd = 0x%x ", ((uint8_t*)(&(cch->cmd)))[0]);
      strcat(buff, buff2);

      sprintf(buff2, "hwaddr = 0x%x ", ((uint8_t*)(&(cch->cmd)))[1]);
      strcat(buff, buff2);

      sprintf(buff2, "mn = 0x%x ", ((uint8_t*)(&(cch->cmd)))[2]);
      strcat(buff, buff2);

      sprintf(buff2, "sensor type = 0x%x ", ((uint8_t*)(&(cch->cmd)))[3]);
      strcat(buff, buff2);

      sprintf(buff2, "parameter = 0x%x ", ((uint8_t*)(&(cch->cmd)))[4]);
      strcat(buff, buff2);
      
      dbg(DBG_USR3, "%s\n", buff);
      */

      configQueryId = cch->queryID;
      configFlag = cch->cmd;
      
      if( cch->nodeID != TOS_LOCAL_ADDRESS )
        {
          dbg(DBG_USR3, "Config message was not for me!\n");

          return SUCCESS;
        }

      dbg(DBG_USR3, "Config message for me!\n");


      switch( cch->cmd )
        {
        case( CONFIG_GET_COMMAND ) :
          {
//            call Leds.greenToggle();

            dbg(DBG_USR3, "Get command\n");
      
            call ChAcceptCmdI.acceptCmd( (char *)(&(cch->cmd)), 5 );
            break;
          }

        case( CONFIG_PUT_COMMAND ) :
          {
//            call Leds.yellowToggle();

            dbg(DBG_USR3, "Put command\n");
      
            call ChAcceptCmdI.acceptCmd( (char *)(&(cch->cmd)), 5 );
            break;
          }

        case( CONFIG_GET_HWADDR_COMMAND ) :
          {
            dbg(DBG_USR3, "Get hwaddr command\n");
            
            call ChAcceptCmdI.acceptCmd( (char *)(&(cch->cmd)), 5 );
            break;
          }

        case( CONFIG_ERASE_COMMAND ) :
          {
            dbg(DBG_USR3, "Erase command\n");      
            call ChAcceptCmdI.acceptCmd( (char *)(&(cch->cmd)), 5 );

            break;
          }

        default :
          {
            return FAIL;
          }
        }

      return SUCCESS;
    }


  event result_t ChAcceptCmdI.acceptCmdDone(char* buf)
    {
      uint8_t response[7];
      QueryResponse_t* qr = (QueryResponse_t*)response;

      /*      
      char buff[1024];
      char buff2[100];
      int i;

      dbg(DBG_USR3, "Config Handler done.  Data is:\n");

      buff[0] = '\0';

      for( i = 0; i < 4; i++ )
        {
          sprintf(buff2, "0x%x ", ((uint8_t*)(buf))[i]);
          strcat(buff, buff2);
        }

      dbg(DBG_USR3, "%s\n", buff);
      */

      switch( configFlag )
        {
        case( CONFIG_GET_HWADDR_COMMAND ) :
        case( CONFIG_GET_COMMAND ) :
          {
            qr->queryID = configQueryId;
            qr->bitMask = 0;
            memcpy( &(qr->data), buf, 4 );

            /*
            dbg(DBG_USR3, "Response:\n");

            buff[0] = '\0';

            for( i = 0; i < sizeof(QueryResponse_t)+4; i++ )
              {
                sprintf(buff2, "%x ", ((uint8_t*)(response))[i]);
                strcat(buff, buff2);
              }

            dbg(DBG_USR3, "%s\n", buff);
            */

            signal QeAcceptQueryI.sendQueryResult( response,
                                                   sizeof(QueryResponse_t)
                                                   + 4 );
            break;
          }

        default :
          {
            //dbg(DBG_USR3, "Response:  fail\n");
            return FAIL;
          }
        }

      return SUCCESS;
    }

  //------------------------------------------------------------------
#if defined(PLATFORM_PC) || defined(PLATFORM_EMSTAR)
  void print_query_header(long long level, char *file, uint32_t line,
                          QueryHeader_t *queryHeader){
    dbg(level,  "%s [%d] -\n"
        "  queryHeader ID    = %d\n"
        "  queryHeader Type  = %d\n"
        "  period      = %d\n"
        "  max epoch   = %d\n"
        "  MN count    = %d\n",
        file, line,
        queryHeader->queryID,
        QUERY_TYPE(queryHeader),
        queryHeader->samplingPeriod,
        queryHeader->maxEpoch,
        queryHeader->mnCnt );
    return;
  }
#endif

  void cancel_all_sampling_jobs(QueryState_t *qtStatePtr){
    uint8_t cnt;
    cnt = oneCnt( qtStatePtr->masterBitMask);
    cancel_sampling_jobs(qtStatePtr, 0, cnt);
  }
  void cancel_sampling_jobs(QueryState_t *qtStatePtr,
                            uint8_t start_index, uint8_t stop_index){
    uint8_t i;
    for( i = start_index; i < stop_index; i++ ){
      if( (qtStatePtr->samplingIDs)[i] != 0 ){
        call DmAcceptMnAndTI.cancelSamplingID( (qtStatePtr->samplingIDs)[ i ] );
      }
    }
  }


  uint16_t set_available_mns(QueryHeader_t *queryHeader){
    uint8_t i;
    uint8_t cnt = 0;
    uint16_t bit = 1;
    uint16_t bitMask = 0;

    // Must check that there are no more than 16 MNs.
    for( i = 0; i < queryHeader->mnCnt && i < MAX_MNS; i++ ) {
      if (mn_set(queryHeader, i) == SUCCESS){
        bitMask |= bit;
        cnt++;
      }
      else if( IS_EXACT_MATCH(queryHeader) ) {
        dbg(DBG_ERROR,  "Fail because exact match isn't satisfied." );
        return 0   ;
      }
      bit <<= 1;
    }
    dbg(DBG_USR3,  "Available MNs = %d", cnt);
    dbg(DBG_USR3,  "bitMask = 0x%0x", bitMask);

    // By this point we have a bitMask indicating which MNs
    // are available.

    // Check if queryHeader can be satisfied.
    // Is there at least one MN available?
    if( cnt == 0 ){
      return 0;
    }
    return bitMask;
  }

  result_t mn_set(QueryHeader_t *queryHeader, uint8_t i){
    return call DmAcceptMnAndTI.mnExist(queryHeader->mn[i]);
  }

  QueryHeader_t *insert_query(QueryHeader_t *queryHeader, uint16_t bitMask){
    QueryHeader_t *qtHeaderPtr;
    QueryState_t *qtStatePtr;
    uint8_t cnt;

    cnt = oneCnt(bitMask);

    // Figure out how much memory we need from the queryTable
    // and ask for it.

    dbg(DBG_USR3,  "QueryHeader Storage Size = %d",
        sizeof(QueryHeader_t) + sizeof(QueryState_t)
        + queryHeader->mnCnt
        + cnt + 2*cnt*(queryHeader->maxEpoch) );

    // This is handled by start_query
    //dbg(DBG_ERROR,  "NEED TO CHECK IF THE SAMPLER CAN HANDLE THE "
    //    "ADDITIONAL SAMPLING LOAD." );

    // param1: the pointer to the queryHeader to be inserted
    // param2: size of the query
    //         (query header + space to store measurement name for
    //         each measurement name)
    // param3: size of extra space needed for query state and data
    //         (query state + a byte to store each sampling id +
    //         storage for data asuming cnt measurements names
    //         and maxEpoch samples per measurement name)

    qtHeaderPtr = (QueryHeader_t*)
      call QueryTableI.insert((uint8_t *)queryHeader,
                              (sizeof(QueryHeader_t) +
                               queryHeader->mnCnt * sizeof(uint8_t)),
                              (sizeof(QueryState_t) +
                               cnt * sizeof(uint8_t)
                               +cnt*(queryHeader->maxEpoch) * sizeof(uint16_t)));
    if (qtHeaderPtr == NULL){
      dbg(DBG_ERROR,  "Fail because queryHeader table couldn't store it." );
      return NULL;
    }
    else {
      qtStatePtr = QUERY_STATE(qtHeaderPtr);
      print_query_header(DBG_USR3, __FILE__, __LINE__, qtHeaderPtr);
      // Write into the qtHeaderPtr's buffer all bookkeeping stuff.
      // first two bytes are the bitmask.
      // second two bytes are the current bit mask.
      // last byte is the time series number.
      qtStatePtr->masterBitMask = bitMask;
      qtStatePtr->slaveBitMask = 0;
      qtStatePtr->curEpoch = 0;
      return qtHeaderPtr;
    }
  }

  result_t start_sampling_all(QueryHeader_t *qtHeaderPtr){
    // Request the appropriate measurement names from the
    // data map.
    uint8_t idx;
    uint16_t bit, bitMask;
    uint8_t i;
    QueryState_t *qtStatePtr;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    bit = 1;
    idx = 0;
    bitMask = qtStatePtr->masterBitMask;

    for( i = 0; i < qtHeaderPtr->mnCnt; i++ ){
      stddbg( "bit = 0x%0x   bitMask = 0x%0x", bit, bitMask );

      if( (bit & bitMask) > 0 ){
        (qtStatePtr->samplingIDs)[idx] =
          call DmAcceptMnAndTI.passMnT( (qtHeaderPtr->mn)[i], qtHeaderPtr->samplingPeriod );

        if( (qtStatePtr->samplingIDs)[idx] == 0 ) {
          // Even though this should never happen
          // since I have already asked the DM
          // if it has the appropriate sensors,
          // but just in case ...

          // Need to add code here to kill query.

          // Cancel exisiting sampling IDs.
          // Using i as an iterator because it is
          // available.
          cancel_sampling_jobs(qtStatePtr, 0, idx);

          // Erase query.
          call QueryTableI.deleteQueryID( qtHeaderPtr->queryID );
          //call Leds.greenOn();
          stddbg1("ERROR: sampler returned a sampling ID of 0");
          return FAIL;
        }

        stddbg( "Sampling ID = %d", (qtStatePtr->samplingIDs)[idx] );

        idx++;
      }
      bit <<= 1;
    }
    return SUCCESS;
  }

  result_t start_sampling_first(QueryHeader_t *qtHeaderPtr){
    // Request the appropriate measurement names from the
    // data map.
    uint8_t idx;
    uint16_t bit, bitMask;
    uint8_t i;
    QueryState_t *qtStatePtr;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    bit = 1;
    idx = 0;
    bitMask = qtStatePtr->masterBitMask;

    for( i = 0; i < qtHeaderPtr->mnCnt; i++ ){
      stddbg( "bit = 0x%0x   bitMask = 0x%0x", bit, bitMask );

      if( (bit & bitMask) > 0 ){
        (qtStatePtr->samplingIDs)[idx] =
          call DmAcceptMnAndTI.passMnT( (qtHeaderPtr->mn)[i], qtHeaderPtr->samplingPeriod );

        if( (qtStatePtr->samplingIDs)[idx] == 0 ){
          // Even though this should never happen
          // since I have already asked the DM
          // if it has the appropriate sensors,
          // but just in case ...

          // Need to add code here to kill query.

          // Cancel exisiting sampling IDs.
          // Using i as an iterator because it is
          // available.
          cancel_sampling_jobs(qtStatePtr, 0, idx);

          // Erase query.
          call QueryTableI.deleteQueryID( qtHeaderPtr->queryID );
          //call Leds.greenOn();
          stddbg1("ERROR: sampler returned a sampling ID of 0");
          return FAIL;
        }

        stddbg( "Sampling ID = %d", (qtStatePtr->samplingIDs)[idx] );

        idx++;
      }

      // Going to add a hack right here.
      // Because the event based queries only need
      // their frist MN sampled initially, I'll
      // break out of this for loop now if
      // I'm an event based query.
      stddbg1( "Break out due to event based sampling.");
      break;
    }
    return SUCCESS;
  }

  result_t start_sampling_rest(QueryHeader_t *qtHeaderPtr){
    // Perform sampling on analog sensors.

    // Start with bit == 2 because we don't want to request
    // the event sensor again, just the analog.
    // In like manner, idx (the sampling ID index) and the
    // index into the list of MNs (i) must start from 1.
    uint16_t bit;
    uint8_t i, idx;
    QueryState_t *qtStatePtr;
    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    bit = 2;
    idx = 1;
    for( i = 1; (i < (qtHeaderPtr->mnCnt)) && (i < MAX_MNS); i++ ) {
      if( (bit & (qtStatePtr->masterBitMask)) > 0 ) {
        // NOTE:  the sampling period specified here is ideally 0,
        // but due to current limitations in the Sampler it has to
        // be 1.
        (qtStatePtr->samplingIDs)[idx] =
          call DmAcceptMnAndTI.passMnT( (qtHeaderPtr->mn)[i], 1 );

        dbg(DBG_USR3,  "Sampling ID = %d", (qtStatePtr->samplingIDs)[idx] );

        idx++;
      }

      bit <<= 1;
    }
    return SUCCESS;
  }

  QueryData_t *store_data(QueryHeader_t *qtHeaderPtr,
                          uint16_t sample, uint8_t samplingID){
    uint8_t i, maxI;
    QueryState_t *qtStatePtr;
    QueryData_t *qtDataPtr;

    qtStatePtr = QUERY_STATE(qtHeaderPtr);

    // maxI holds the total number of sampling IDs running for
    // this query.
    maxI = oneCnt(qtStatePtr->masterBitMask);

    // In order to find where the data starts we need to know the
    // number of sampling IDs (stored into maxI).
    qtDataPtr = (QueryData_t*)((uint8_t*)(qtHeaderPtr) +
                               sizeof(QueryHeader_t) +
                               qtHeaderPtr->mnCnt +
                               sizeof(QueryState_t) + maxI);


    // Need to figure out where this data goes.
    // Find the list of sampling IDs
    // i holds the index of the associated sampling ID.
    for( i = 0; ((qtStatePtr->samplingIDs)[i]!=samplingID) && (i<maxI); i++)
      {}

    // Here, check if i >= maxI.  If so, then no such sampling ID
    // was found for this queryHeader (which would be very odd seeing
    // as the queryHeader table gave us the pointer to the query.
    if( i >= maxI ) {
      dbg(DBG_ERROR,  "Sampling index > max index.  Fail.  Cancel job for safety." );
      call DmAcceptMnAndTI.cancelSamplingID( samplingID );
      return NULL;
    }

    // Store the sample.
    // Given the qPtr and the maxI we can find where the
    // data begins to be stored.  After that we want to
    // index into the data store.  epoch*maxI will get
    // you to the correct storage for this epoch, and i
    // is the index within that epoch where this data
    // should be stored.
    if ((qtStatePtr->curEpoch)*maxI > 255)
    {
        dbg(DBG_ERROR, "Potential problem: epoch*maxI may be larger than 255\n");
    }
    (qtDataPtr->data)[ (qtStatePtr->curEpoch)*maxI + i ] = sample;

    dbg(DBG_USR3,  "Data stored" );

    dbg(DBG_USR3,  "Master before store = %d", qtStatePtr->masterBitMask );
    dbg(DBG_USR3,  "Slave before store = %d", qtStatePtr->slaveBitMask );
    dbg(DBG_USR3,  "Bit to flip = %d", i );

    // Flip the bit in the current bit mask to indicate data has been stored.
    flipBit( &(qtStatePtr->masterBitMask),
             &(qtStatePtr->slaveBitMask), i );

    dbg(DBG_USR3,  "Master after store = %d", qtStatePtr->masterBitMask );
    dbg(DBG_USR3,  "Slave after store = %d", qtStatePtr->slaveBitMask );

    return qtDataPtr;
  }

  QueryHeader_t *get_query(uint8_t samplingID){
    QueryHeader_t *qtHeaderPtr;
    // Grab the queryHeader associated with the sampling ID.
    qtHeaderPtr = (QueryHeader_t*) call QueryTableI.request( samplingID );
    if( qtHeaderPtr == NULL ) {
      stddbg( "Couldn't find queryHeader associated with sampling ID = %d. Cancelling sampling ID", samplingID );
      call DmAcceptMnAndTI.cancelSamplingID( samplingID );
      return NULL;
    }
    else {
      stddbg( "Found queryHeader associated with sampling ID = %d", samplingID );
      return qtHeaderPtr;
    }
  }

  void send_data(QueryHeader_t *qtHeaderPtr,
                 QueryData_t *qtDataPtr, uint8_t qRespDataLen){
    uint8_t iter;
    QueryResponse_t* qResp;
    QueryState_t *qtStatePtr;
    uint8_t qRespData[ QH_MAX_RESPONSE_SIZE ];

    dbg(DBG_USR3,  "Sending Data" );


    qtStatePtr = QUERY_STATE(qtHeaderPtr);

    // Round qRespDataLen to be <= 61
    // (which is the size of the buffer - size of the response header).
    if( sizeof(int16_t) * qRespDataLen > (QH_MAX_RESPONSE_SIZE - sizeof(QueryResponse_t)) ){
      qRespDataLen = (QH_MAX_RESPONSE_SIZE - sizeof(QueryResponse_t)) / sizeof(int16_t);
    }
    //call Leds.set(0x3 & qRespDataLen);

    qResp = (QueryResponse_t*)(qRespData);
    qResp->queryID = qtHeaderPtr->queryID;
    qResp->bitMask = qtStatePtr->masterBitMask;

    for( iter = 0; iter < qRespDataLen; iter++ ){
      qResp->data[iter] = qtDataPtr->data[iter];
    }

    // Notice that we are using 2*qRespDataLen.  This is
    // because each sensor data entry is 2 bytes long.
    signal QeAcceptQueryI.sendQueryResult( (uint8_t*)(qRespData),
                                           sizeof(QueryResponse_t)
                                           + sizeof(int16_t) * qRespDataLen );
    // Now we set curEpoch to zero!!!
    // Reset the epoch counter.
    qtStatePtr->curEpoch = 0;

    // For now we will put the sympathy counter here, even though
    // we don't know if it was sucessfully sent
#ifdef SYMPATHY_DSE
    stats.num_pkts_tx++;
#endif
  }

  result_t valid_sampling_id(uint8_t samplingID){
    // A samplingID of 0 is illegal.  The reason for this is that
    // in the querytable a 0 is stored in the place of an invalid
    // sampling job.
    if( samplingID == 0 ) {
      stddbg1("ERROR: passData got sampling ID of 0. Cancelling job.");
      // Just for safety, even though it is not possible
      // cancel the job.
      call DmAcceptMnAndTI.cancelSamplingID( 0 );
      return FAIL;
    }
    return SUCCESS;
  }

  bool all_samples_received(QueryHeader_t *qtHeaderPtr){
    QueryState_t *qtStatePtr;
    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    if (qtStatePtr->masterBitMask == qtStatePtr->slaveBitMask){
      stddbg1("Single sample has matching bit masks.");
      qtStatePtr->slaveBitMask = 0;
      // call Leds.set(0x7 & qtStatePtr->masterBitMask);
      return TRUE;
    }
    else {
      stddbg1("bitmasks don't match");
      return FALSE;
    }
  }

  bool time_to_send(QueryHeader_t *qtHeaderPtr){
    QueryState_t *qtStatePtr;
    qtStatePtr = QUERY_STATE(qtHeaderPtr);
    // If epochs match then it is time to send.
    if (qtStatePtr->curEpoch == qtHeaderPtr->maxEpoch){
      stddbg1( "Max epoch reached. Send queryHeader result." );
      qtStatePtr->curEpoch = 0;
      return TRUE;
    }
    return FALSE;
  }

}
