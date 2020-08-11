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
 *  Move robot to position2d x,y and angle a
 */

#include "setposition.h"
#include <math.h>

#define THRESHOLD_ANG 0.05
#define THRESHOLD_DISTANCE 0.20

//#define DEBUG

void get_angdist (double x0, double y0, double x1, double y1, double cur_ang, double *ang, double *dist){

  double dx, dy;

  dx = x1-x0;
  dy = y1-y0;

	*ang=atan2(dy,dx);
  *dist=sqrt(dx*dx+dy*dy);

}

void playerc_position2d_set_cmd_turn(playerc_client_t *cli, playerc_position2d_t *pos, double ang, double w){

	playerc_client_read(cli);

	#ifdef DEBUG
	printf("\nPosition Angle=:%.3f Need angle=%.3f ABS=%f",pos->pa,ang, fabs(pos->pa - ang));
	#endif

  double positive_pa,positive_ang;

  //calculate to which side to move. need to transform from -pi, pi to 0,2pi.
  positive_pa=pos->pa;
  if(positive_pa<0.0){positive_pa+=(2*M_PI);}
  positive_ang=ang;
  if(positive_ang<0.0){positive_ang+=(2*M_PI);}
  //if negative, should go anit-clockwise
  if((positive_pa-positive_ang)>0.0){w*=-1;}
  if(fabs(positive_ang-positive_pa)>M_PI){w*=-1;}

  while ( fabs(pos->pa - ang)>THRESHOLD_ANG) {
		playerc_position2d_set_cmd_vel(pos, 0, 0, w, 1);
		playerc_client_read(cli);

		#ifdef DEBUG
		printf("\nPosition Angle=:%.3f Need angle=%.3f",pos->pa,ang);
		#endif

	}

	playerc_position2d_set_cmd_vel(pos, 0, 0, 0, 0);

}

void playerc_position2d_set_cmd_go_ahead(playerc_client_t *cli, playerc_position2d_t *pos, double dis, double vel){

  double dx,dy;
	double old_x,old_y;
  double dis2,current_dist2;

	playerc_client_read(cli);

  dis2=dis*dis;

  old_x=pos->px;
  old_y=pos->py;

	current_dist2=0.0;

  while ( (dis2 - (current_dist2+THRESHOLD_DISTANCE) )>0) {
		playerc_position2d_set_cmd_vel(pos, vel, 0, 0, 1);
		playerc_client_read(cli);
		dx=old_x-pos->px;
		dy=old_y-pos->py;
    current_dist2=dx*dx+dy*dy;

		#ifdef DEBUG
		printf("\nMoved^2=:%.3f Need^2 =%.3f. We are at %.3f,%.3f",current_dist2,dis2,pos->px,pos->py);
		#endif
	}

	playerc_position2d_set_cmd_vel(pos, 0, 0, 0, 0);

}


void playerc_position2d_set_cmd_position2d(playerc_client_t *cli, playerc_position2d_t *pos,double x,double y,double vel,double w){

	double dist;
	double ang;

get_angdist(pos->px,pos->py,x,y,pos->pa,&ang,&dist);
#ifdef DEBUG
printf("\nAngle=:%.3f Distance=%.3f",ang,dist );
#endif

playerc_position2d_set_cmd_turn(cli, pos, ang, w);
playerc_position2d_set_cmd_go_ahead(cli, pos, dist, vel);

}

