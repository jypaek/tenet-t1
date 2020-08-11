#include <stdio.h>
#define LINESIZE 80



FILE* binfileout=NULL;

//defined in harware.h to get around ncc component mangling
//char* memfilename = "/home/rkapur/main_yellow_mica2.srec";
//char* memcpy_filename;


void emtos_init_inst_rom(int argc, char* argv[]);
int emtos_read(FILE* f, char* buff, int size);
int parse_srec_file(FILE* f, FILE* fo);
int emtos_memcpy_init(char* fname);
int memcpy_P(uint8_t* buffer, long int addr, int size);


void emtos_init_inst_rom(int argc, char* argv[]){

  int i;
  for (i=0;i<argc;i++){
    if(strncmp(argv[i],"--inst_rom",10) == 0){
      memcpy_filename=argv[i+1];
    }
  }
  
  
  if(memcpy_filename == NULL){
    return;
  }
  
  printf("instruction rom init: file name is %s\n",memcpy_filename);
  fflush(stdout);

}



int emtos_memcpy_init(char* fname){
  
  FILE* file;
  FILE* fileout;
  char foname[strlen(fname)+10];

  if(fname == NULL){
    return -1;
  }

  if(binfileout != NULL){
    return 0;
  }

  
  memset(foname,'\0',strlen(fname)+10);
  memcpy(foname,fname,strlen(fname));

  file = fopen(fname,"r");
  fileout = fopen(strcat(foname,".mica2bin"),"w+");

  if(file == NULL){
    perror("File could not be opened\n");
    fflush(stdout);
    return -1;
  }

  if(fileout == NULL){
    perror("Fileout could not be opened\n");
    fflush(stdout);
    return -1;
  }

  parse_srec_file(file,fileout);

  fclose(file);
  fclose(fileout);

  binfileout = fopen(foname,"r");	
  if(binfileout == NULL){
    perror("Fileout could not be opened\n");
    fflush(stdout);
    return -1;
  }

  return 0;
}

int memcpy_P(uint8_t* buffer, long int addr, int size){

  int i=0;

  if (binfileout == NULL){
    if(memcpy_filename != NULL){
      if (emtos_memcpy_init(memcpy_filename) < 0){
	printf("emtos_init_inst_rom: unable to load SREC file specified\n");
	fflush(stdout);
      }
    }
    buffer = NULL;
    printf("Fileout is not defined for file %s at addr %04x. \n",memcpy_filename, &(memcpy_filename));
    fflush(stdout);
    return -1;
  }
  
  if (fseek(binfileout,addr,SEEK_SET) != 0){
    buffer = NULL;
    printf("Fseek failed \n");
    fflush(stdout);
    return -1;
  }
 
  for(i=0;i<size;i++){   
    if (feof(binfileout)!=0){
      printf("File hit end of file\n");
      fflush(stdout);
      return i;
    }else{
      char c =  fgetc(binfileout);
      uint8_t d = (uint8_t) c;
      buffer[i]=d; 
    }
  }
  return size;
}


int emtos_read(FILE* f, char* buff, int size){
  int i = 0;
  for(i=0;i<size;i++){
    if(feof(f) == 0){
      buff[i] = fgetc(f);
    }else{
      return i-1;
    }
  }
  return size;
}


int parse_srec_file(FILE* f, FILE* fo){
  char idbuf[2]={0};
  char linebuf[LINESIZE]={0};
  char binbuf[LINESIZE]={0};
  int16_t linelength=0;
  int8_t type=-1;
  int16_t n=0;
  int retval=0;
  
  int16_t linecount=0;
  int32_t bytecount=0;
  int i=0;
  int j=0;
  
  while(1) {
    memset(idbuf, 0, 2);
    n = emtos_read(f, idbuf, 2);
    if (n < 0) {
      retval = -1;
      goto done;
    }
    
    
    if (idbuf[0] != 'S' || ((idbuf[1] != '0') && (idbuf[1]!='1') && (idbuf[1]!='9'))) {
      if (idbuf[0]==0 && idbuf[1]==0) {
	// eof, most likely
	retval = 0;
	goto done;
      } else {
	retval = -1;
	goto done;
      }
    }
    
    
    // discover the srec type
    switch (idbuf[1]) {
      case '0':
	type=0;
	break;
      case '1':
	type=1;
	break;
      case '9':
	type=9;
	break;
      default:
	break;
    }
    
    
    // figure out the length
    n = emtos_read(f, idbuf, 2);
    if (n < 0) {
      retval = -1;
      goto done;
    }
    // srec is an ascii file.
    // The length is in hex format, so I am converting
    // it to hex
    linelength=strtol(idbuf, NULL, 16);
    
    linelength+=1;  // 1 for crc, 1 for the 'n'
    
    
    // now read 2*linelength into the linebuf. 2*ll will read UP TO AND
    // INCLUDING the \n, so now the fpointer is at the beginning of the next
    // line
    n=emtos_read(f, linebuf, 2*linelength);
    if (n < 0) {
      retval = -1;
      goto done;
    }
    
    //we skip over the S0 record
    if (type == 0 || type == 9){
      continue;
    }
	
    j=0;
    for (i=0; i<2*linelength-2; i+=2) {
      if (linebuf[i]!='\n') {
	uint8_t num=0;
	uint8_t tmp[4]={0};
	if (linebuf[i+1]!='\n') {
	  memcpy(&tmp, linebuf+i, 2);
	  num=strtol(tmp, NULL, 16);
	  binbuf[j]=num;
	  j++;
	} else {
	  // i am at the last char of the line
	  memcpy(&tmp, linebuf+i, 2);
	  tmp[1]='\0';
	  num=strtol(idbuf, NULL, 16);
	  binbuf[j]=num;
	  j++;
	}
	if (j>=linelength) {
	  break;
	}
      }
    }
    
    for (i=2; i<linelength-2; i++) {
      putc((uint8_t)binbuf[i],fo);
    }
    fflush(fo);
    
    
    linecount++;
    bytecount+=(linelength-1);  // -1 for the extra last byte
    
  }
  
 done:
  if (retval >= 0) {
    /*  
    printf("lines=%d, bytes=%d\n", linecount, bytecount);
    fflush(stdout);
    */
  }
  return retval;
  
}


