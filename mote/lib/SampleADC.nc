/*
 * Interface between platform dependant and independant parts of sampling.
 *
 * @author August Joki
*/

interface SampleADC {
    command void init();
    command void start();
    command void stop();
    command bool validChannel(uint8_t channel);
    command result_t getData(uint8_t channel);
    async event uint16_t dataReady(uint16_t data);
    event result_t error(uint8_t token);
}

