/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/*
* Authors: Marcos Augusto Menezes Vieira
* Embedded Networks Laboratory, University of Southern California
*/
/*
 * Set of function to be able to use the VFH and robot Pioneer
 * Read data of a particle filter from a file and on endpoints correct robot moviment
 * Need to calculate the position2d from robot wrong point of view (odometer).
 */
#include <playerc.h>
#include "planning.h"
#include "setposition.h"
#include <math.h>
#include "plan_vfh.h"

#define THRESHOLD_ANG_MIN 0.10  // minimum angle(radians) close to goal to stop rotate
#define THRESHOLD_ANG_MAX 0.40  //maximum diference angle (radians) to not start rotate
#define ANGULAR_VEL 0.4  //angular velocity to rotate (radians/sec)
//#define DEBUG


//global variables

FILE *localization_file;//particle filter file
FILE *logfile;
//robot
playerc_client_t *client;
playerc_position2d_t *position2d;  //VFH position2d
playerc_position2d_t *position2dRaw;  //Motors position2d
//value of particle filter
double xAbsolute;
double yAbsolute;
double aAbsolute;
int pfFlag;


///////Particle Filter //////////////

//read file of particle filter to get correct position2d
void getPosition(FILE *localization_file){

  if(fscanf(localization_file, "%d %lf %lf %lf", &pfFlag, &xAbsolute, &yAbsolute, &aAbsolute)!=4){
    fprintf(logfile,"ERROR READING LOCALIZATION FILE!!!!\n");
  };
  //fprintf(logfile, "\r%i %.2lf %.2lf %.2lf", pfFlag, xAbsolute, yAbsolute, aAbsolute);

  fseek(localization_file, 0, SEEK_SET);
  //printf("%i %.2lf %.2lf %.2lf", pfFlag, xAbsolute, yAbsolute, aAbsolute);

}

///////////Navigation ////////////

double get_ang (double x0, double y0, double x1, double y1){

  double dx, dy;
  double ang;

  dx = x1-x0;
  dy = y1-y0;

  ang=atan2(dy,dx);

  return ang;
}


void my_playerc_position_set_cmd_turn(double goal_x,double goal_y){

  double w;
  double moveAng;
  double tarAng;
  getPosition(localization_file);
  tarAng=get_ang(xAbsolute,yAbsolute,goal_x,goal_y);

  w=ANGULAR_VEL;

  //playerc_client_read(client);
  moveAng=tarAng-aAbsolute;
  while(moveAng>M_PI){moveAng-=(2*M_PI);}
  while(moveAng<-M_PI){moveAng+=(2*M_PI);}

  if(moveAng<0){w=w*-1;}//calculate to rotate clockwise or anti-clockwise

  playerc_client_read(client);

  #ifdef DEBUG
  printf("\nRotating");
  printf("\nAbs Pos x:%.2lf y:%.2lf a:%.2lf",xAbsolute,yAbsolute,aAbsolute);
  printf("\nAbs Tar x:%.2lf y:%.2lf",goal_x,goal_y);
  printf("\nCur Pos x:%.2lf y:%.2lf a:%.2lf",position2d->px,position2d->py,position2d->pa);
  printf("\nCur Tar a:%.2lf",tarAng);
  printf("\nCurrently distance from target a:%.2lf\n",moveAng);
  #endif

  if(fabs(moveAng)>THRESHOLD_ANG_MAX){
  //if it need to correct ang, rotate

    playerc_position2d_set_cmd_vel(position2dRaw,0.0,0,w,1);
    do{
      playerc_client_read(client);
      getPosition(localization_file);
      moveAng=tarAng-aAbsolute;
      while(moveAng>(M_PI)){moveAng-=(2*M_PI);}
      while(moveAng<(-M_PI)){moveAng+=(2*M_PI);}
      moveAng=fabs(moveAng);

      #ifdef DEBUG
      printf("\rAbs ang=%.2lf Target=%.2lf Need to Move=%.2lf pa=%.2lf",aAbsolute,tarAng,moveAng,position2d->pa);
      #endif

    }while(moveAng>THRESHOLD_ANG_MIN);

    playerc_position2d_set_cmd_vel(position2dRaw,0,0,0,0);
    //sleep(5);
  }//end if

}

void my_playerc_position_set_cmd_pose(double goal_x,double goal_y){

  double dx,rotatex;
  double dy,rotatey;
  double teta;

  double px;
  double py;
  double pa;

  //first rotate
  my_playerc_position_set_cmd_turn(goal_x,goal_y);

  //transform coordinate system from Particle Filter to Position driver in Robot system
  playerc_client_read(client);
  px=position2d->px;
  py=position2d->py;
  pa=position2d->pa;

  getPosition(localization_file);

  teta=aAbsolute - pa;
  dx=goal_x-xAbsolute;
  dy=goal_y-yAbsolute;

  rotatex=dx*cos(teta)+dy*sin(teta);
  rotatey=dy*cos(teta)-dx*sin(teta);

  rotatex+=px;
  rotatey+=py;

  #ifdef DEBUG
  printf("\nTranslation");
  printf("\nAbs Pos x:%.2lf y:%.2lf a:%.2lf",xAbsolute,yAbsolute,aAbsolute);
  printf("\nAbs Tar x:%.2lf y:%.2lf",goal_x,goal_y);
  printf("\nRaw Pos x:%.2lf y:%.2lf a:%.2lf",position2dRaw->px,position2dRaw->py,position2d->pa);
  printf("\nCur Pos x:%.2lf y:%.2lf a:%.2lf",px,py,pa);
  printf("\nCur Tar x:%.2lf y:%.2lf \n\n",rotatex,rotatey);
  #endif

  //sleep(5);

  playerc_position2d_set_cmd_pose(position2d,rotatex,rotatey,0,1);

  while((position2d->vx==0.0)&&(position2d->vy==0.0)&&(position2d->va==0.0)){
    playerc_client_read(client);
    #ifdef DEBUG
    fprintf(logfile, "px=%.2lf py=%.2lf pa=%.2lf teta=%.2lf rotatex=%.2lf rotatey=%.2lf xAbsolute=%.2lf yAbsolute=%.2lf aAbsolute=%.2lf dist_x=%.2lf dist_y=%.2lf \n",position2d->px,position2d->py,position2d->pa,teta,rotatex,rotatey,xAbsolute,yAbsolute,aAbsolute,(rotatex-position2d->px),(rotatey-position2d->py));
    #endif

  }

  double distanceX,distanceY;
  distanceX=rotatex-position2d->px;
  distanceY=rotatey-position2d->py;
  distanceX=distanceX*distanceX;
  distanceY=distanceY*distanceY;

  while( ((position2d->vx!=0.0)||(position2d->vy!=0.0)||(position2d->va!=0.0) )||((distanceX+distanceY)>1.0)){
    getPosition(localization_file);
    playerc_client_read(client);

    #ifdef DEBUG
    fprintf(logfile, "Moving...px=%.2lf py=%.2lf pa=%.2lf teta=%.2lf rotatex=%.2lf rotatey=%.2lf xAbsolute=%.2lf yAbsolute=%.2lf aAbsolute=%.2lf dist_x=%.2lf dist_y=%.2lf \n",position2d->px,position2d->py,position2d->pa,teta,rotatex,rotatey,xAbsolute,yAbsolute,aAbsolute,(rotatex-position2d->px),(rotatey-position2d->py));
    printf("\rdist_x=%.2lf dist_y=%.2lf (%.2lf, %.2lf, %.2lf)",(rotatex-position2d->px),(rotatey-position2d->py),position2d->px,position2d->py,position2d->pa*180/M_PI);
    #endif

    distanceX=rotatex-position2d->px;
    distanceY=rotatey-position2d->py;
    distanceX=distanceX*distanceX;
    distanceY=distanceY*distanceY;

  }

}

void openfiles(){
 //open particle filter file

  localization_file=fopen("pf_loc/src/localization","r");
  //localization_file=fopen("pf2/localization","r");
  if (localization_file==NULL){
       printf("\nFile Error\nTrying to open:'%s'\n","localization");
         exit(1);
  }

  //open logfile

  logfile=fopen("log","w");
  if (logfile==NULL){
       printf("\nFile Error\nTrying to open:'%s'\n","logfile");
         exit(1);
  }


}

void initRobot(){

//initialize robot

  // Create a client object and connect to the server; the server must
  // be running on "IP" at port 6665

/// client = playerc_client_create(NULL,"localhost", 6665);
//  client = playerc_client_create(NULL, "10.0.0.82", 6665);
//  client = playerc_client_create(NULL, "192.168.0.82", 6665);
  client = playerc_client_create(NULL, "192.168.0.36", 6665);

  if (playerc_client_connect(client) != 0){
    fprintf(stderr, "error: %s\n", playerc_error_str());
    exit(1);
  }

  ///////////////VFH//////////////////////

  // Create a position2d proxy (device id "position2d:0") and susbscribe
  // in read/write mode
  position2d = playerc_position2d_create(client, 0);
  if (playerc_position2d_subscribe(position2d, PLAYER_ALL_MODE) != 0){
    fprintf(stderr, "error: %s\n", playerc_error_str());
    exit(1);
  }

  // Enable the robots motors
  playerc_position2d_enable(position2d, 1);


  ///// Motor Controllers//////////////////

  // Create a position2d proxy (device id "position2d:1") and susbscribe
  // in read/write mode
  position2dRaw = playerc_position2d_create(client,1);
  if (playerc_position2d_subscribe(position2dRaw, PLAYER_ALL_MODE) != 0){
    fprintf(stderr, "error: %s\n", playerc_error_str());
    exit(1);
  }
  // Enable the robots motors
  playerc_position2d_enable(position2dRaw, 1);

  ///end motor controllers

}

void initRobotSystem(){
 openfiles();
 initRobot();
}

void closeFiles(){

  //close files
  fclose(localization_file);
  fclose(logfile);

}

void closeRobot(){
    //close robot
    // Shutdown and tidy up
  //  playerc_position2d_set_cmd_vel(position2d, 0, 0, 0, 0);
  playerc_position2d_unsubscribe(position2dRaw);
  playerc_position2d_destroy(position2dRaw);
  playerc_position2d_unsubscribe(position2d);
  playerc_position2d_destroy(position2d);
  playerc_client_disconnect(client);
  playerc_client_destroy(client);
}

void closeRobotSystem(){
  closeFiles();
  closeRobot();
}

/*int main(int argc,char *argv[]){

  //read graph topology
  double **matrix;
  node_t* nodes;
  int nVertex;

  if(argc<2){
    printf("Incorrect parameter. Usage: test_plan filename\n");
    exit(1);
  }

  initRobotSystem();

  //load topology
  printf("Loading topology...\n");
  loadTopology(argv[1],&matrix,&nodes,&nVertex);
  printf("Topology loaded\n");


//  playerc_position2d_set_cmd_pose(position2d, 1.0, 0.0, 0, 1);
//  playerc_position2d_set_cmd_vel(p2, 0.2, 0, 0, 1);

  int old_position2d=0;
  int initial_position2d=0;
  printf("What is the initial position2d?\n");
  scanf("%d",&initial_position2d);
  old_position2d=initial_position2d;

  vector<int> path;

  while(1){
    int new_position2d=0;

    //read input
    printf("\nWhich position2d to move? 0 to %d. (-1 to quit.):",nVertex);
    scanf("%d",&new_position2d);
    if(new_position2d<0)break;

    path=plan(old_position2d,new_position2d,matrix,nVertex);
    printf("Moving from %d to %d\n",old_position2d,new_position2d);
    fprintf(logfile,"Moving from %d to %d\n",old_position2d,new_position2d);
    printf("Doing the plan:");
    printPath(path);

    int indx;
    for (indx =path.size()-2;indx>=0; indx--){//-2 because the last position2d is the current position2d.

      fprintf(logfile,"\nGoing to Pos x: %.2lf y: %.2lf id:%d\n",nodes[path[indx]].x,nodes[path[indx]].y,path[indx]);
      printf("\nGoing to Pos x: %.2lf y: %.2lf id:%d\n",nodes[path[indx]].x,nodes[path[indx]].y,path[indx]);

      my_playerc_position_set_cmd_pose(nodes[path[indx]].x,nodes[path[indx]].y);

    }

    old_position2d=new_position2d;
  }

  closeRobotSystem();
  //close planning
  free(matrix);
  free(nodes);

  return 0;
}*/

