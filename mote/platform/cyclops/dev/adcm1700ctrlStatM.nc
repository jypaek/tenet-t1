// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

includes adcm1700Const;
includes memConst;

module adcm1700ctrlStatM
{
    provides {
        interface StdControl as StdControlStat;
        interface ctrlStat as stat;
    }
    uses {
        interface imagerComm;        
    }
}
implementation
{

    color16_t values;

    //*******************Inititialization and Termination*********************/
    command result_t StdControlStat.init() 
        {
            values.red = 0;
            values.green = 0;
            values.blue = 0;

            return SUCCESS;
        }
    
    command result_t StdControlStat.start() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlStat.stop() 
        {
            return SUCCESS;
        }

    //***********************Format Control*********************/
    command result_t stat.getSums()
        {
            // The following registers are present only in the second revision 
            // of the ADCM-1700. The register value is equal to the sum of all
            // of the pixels (of that color) in the input window, divided by 16384.
            // Obviously this function is not usefull when there are few pixels in
            // the input window. To get the average pixel value, divide by (nx * ny / 4).

            call imagerComm.readRegister(ADCM_REG_SUM_GRN1);

            return SUCCESS;
        }

    default event result_t stat.getSumsDone(color16_t vals, result_t status)
        {
            return SUCCESS;
        }

    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            return SUCCESS;
        }

    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status != SUCCESS)
                {
                    signal stat.getSumsDone(values, FAIL);
                    return SUCCESS;
                }

            switch (addr)
                {
                case ADCM_REG_SUM_GRN1:
                    values.green = data >> 1;
                    call imagerComm.readRegister(ADCM_REG_SUM_RED);
                    break;
                case ADCM_REG_SUM_RED:
                    values.red = data;
                    call imagerComm.readRegister(ADCM_REG_SUM_BLUE);
                    break;
                case ADCM_REG_SUM_BLUE:
                    values.blue = data;
                    call imagerComm.readRegister(ADCM_REG_SUM_GRN2);
                    break;
                case ADCM_REG_SUM_GRN2:
                    values.green = values.green + (data >> 1);
                    signal stat.getSumsDone(values, SUCCESS);
                    break;
                default:
                    signal stat.getSumsDone(values, FAIL);
                    break;
                }

            return SUCCESS;
        }

    //***********************Writing and Reading Blocks*********************/
    event result_t imagerComm.writeBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status)
        {
            return SUCCESS;
        }
    
    event result_t imagerComm.readBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status) 
        {
            return SUCCESS;
        }

}
