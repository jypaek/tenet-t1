#include <gtk/gtk.h>
#include <math.h>
#include <stdlib.h>
#include <sys/time.h>

#include <pthread.h>
#include <stdio.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>

#include "draw.h"
#include "playerc.h"

#define MAX_PARTICLES 5000

double mean_x=0, mean_y=0, mean_a=0, stdev_x=0, stdev_y=0;
FILE* locFile;

     int n;
     char out[512];

typedef struct st_print_par PPAR;
struct st_print_par
	{
	float mx, my, bx, by;
	};

PPAR ppar;

typedef struct st_map MAP;
struct st_map
	{
	int size_x;
	int size_y;
	int grid[700][500];
	int lh_grid[700][500];
	float scale;	// (grids/m)
	};

MAP map;

typedef struct st_part PARTICLE;
struct st_part
	{
	float x, y, a;
	unsigned w;
	unsigned accw;
	int valid;
	};

PARTICLE particle[MAX_PARTICLES];

playerc_client_t *client;
playerc_position_t *position;
playerc_laser_t *laser;

extern int gui;

void load_map(char *map_file_name)
	{
	int i, j, aux;
	FILE *map_file;

	map_file=fopen("rth.map","r");
	if (map_file==NULL)
		{
		printf("\nFile Error\nTrying to open:'%s'\n",map_file_name);
		return 1;
		}

	fscanf(map_file,"mapd %i %i",&map.size_x, &map.size_y);
	printf("\nLoading map with dimensions x:%i, y:%i", map.size_x, map.size_y);

	for(i=0; i<map.size_y; i++)	//x and y inverted
	for(j=0; j<map.size_x; j++)
		{
		fscanf(map_file,"%i\n",&aux);
		if (aux== 1) map.grid[j][i]= 1;
		if (aux== 0) map.grid[j][i]=-1;
		if (aux==-1) map.grid[j][i]= 0;
		}
	}

void print_map(void)
	{
	int i, j;

	for(i=0; i<map.size_x; i++)
	for(j=0; j<map.size_y; j++)
		{
		if (map.grid[i][j] == 1)		draw_point(i, j, 0, 1);
		if (map.grid[i][j] == 0)		draw_point(i, j,11, 1);
		if (map.grid[i][j] == -1)		draw_point(i, j, 4, 1);
		}
	}

void print_lh_map(void)
	{
	int i, j;

	for(i=0; i<map.size_x; i++)
	for(j=0; j<map.size_y; j++)
		{
		if (map.lh_grid[i][j] == 49)		draw_point(i, j,  0, 1);
		if (map.lh_grid[i][j] == 36)		draw_point(i, j, 10, 1);
		if (map.lh_grid[i][j] == 25)		draw_point(i, j, 11, 1);
		if (map.lh_grid[i][j] == 16)		draw_point(i, j, 12, 1);
		if (map.lh_grid[i][j] ==  9)		draw_point(i, j, 13, 1);
		if (map.lh_grid[i][j] ==  4)		draw_point(i, j, 14, 1);
		if (map.lh_grid[i][j] ==  2)		draw_point(i, j, 15, 1);
		}
	}


void calc_lh_map(void)
	{
	int i,j,k,dist;
	int aux1s, aux1f, aux2s, aux2f;
	int lh_value[]={50, 2, 0, 0, 0, 0, 0};

	printf("\nCalculating Likelyhood Map...");

	for(i=0; i<map.size_x; i++)
	for(j=0; j<map.size_y; j++)
		map.lh_grid[i][j]=0;


	for(dist=6; dist>=0; dist--)
	for(i=0; i<map.size_x; i++)
	for(j=0; j<map.size_y; j++)
		{
		aux1s=i-dist; if (aux1s<0)   aux1s=0;
		aux1f=i+dist; if (aux1f>=map.size_x) aux1f=map.size_x-1;

		aux2s=j-dist; if (aux2s<0)   aux2s=0;
		aux2f=j+dist; if (aux2f>=map.size_y) aux2f=map.size_y-1;

		for (k=aux1s; k <=aux1f; k++)
			{
			if (map.grid[k][aux2s]==1) map.lh_grid[i][j]=lh_value[dist];
			if (map.grid[k][aux2f]==1) map.lh_grid[i][j]=lh_value[dist];
			}

		for (k=aux2s; k <=aux2f; k++)
			{
			if (map.grid[aux1s][k]==1) map.lh_grid[i][j]=lh_value[dist];
			if (map.grid[aux1f][k]==1) map.lh_grid[i][j]=lh_value[dist];
			}
		}
	printf(" Done.");
	}


inline void rand_position(float *rx, float *ry, float *ra)
	{
		*rx = (rand() % map.size_x*100)/(map.scale*100);
		*ry = (rand() % map.size_y*100)/(map.scale*100);
		*ra=((rand()%62)-31)/10.0;

		while (map.grid[(int)((*rx) * map.scale)][map.size_y- ((int)((*ry) * map.scale))]!=-1)
			{
			*rx = (rand() % map.size_x*100)/(map.scale*100);
			*ry = (rand() % map.size_y*100)/(map.scale*100);
			}
	}


void init_particles2(float x, float y, float a)
	{
	int i;
	float var_xy=0.5, var_a=0.12;

	printf("\nInitializing particles...");


	for (i=0; i<MAX_PARTICLES; i++)
		{
		particle[i].x= x + (((rand()%2000*var_xy)/1000.0)-var_xy);
		particle[i].y= y + (((rand()%2000*var_xy)/1000.0)-var_xy);
		particle[i].a= a + (((rand()%2000*var_a) /1000.0)- var_a);

		particle[i].w=0;
		}

	printf("Done.");

	}


void init_particles(void)
	{
	int i;
	float  rfx, rfy, rfa;

	printf("\nInitializing random particles...");

	for (i=0; i<MAX_PARTICLES; i++)
		{
		rand_position(&rfx, &rfy, &rfa);

		particle[i].x=rfx;
		particle[i].y=rfy;
		particle[i].a=rfa;

		particle[i].w=0;
		}

	printf("Done.");

	}


inline void refresh_screen(void)
	{
	gdk_threads_enter();
//	gdk_draw_drawable(darea->window,  gcont,  pixmap, 0, 0, 0, 0, map.size_x, map.size_y);
	gdk_draw_drawable(darea->window,  gcont,  pixmap, 0, 0, 0, 0, 700, 500);
	gdk_threads_leave();

	gdk_threads_enter();
	gdk_flush();
	gdk_threads_leave();

//	gdk_threads_enter();
//	clear_screen();	
//	gdk_threads_leave();
	}


void print_particles(void)
	{
	int i, ix, iy;

	for (i=0; i<MAX_PARTICLES; i++)
		{
		ix=particle[i].x*map.scale;
		iy=map.size_y-(particle[i].y*map.scale);
		if ((ix<0) ||(ix>=map.size_x) || (iy<0) ||(iy>=map.size_y)) continue;
		if(map.grid[ix][iy]==-1) draw_point(ix, iy, 1, 1);
		}

	ix=ppar.mx * map.scale;
	iy=map.size_y-(ppar.my * map.scale);
	if ((ix>0) && (ix<=map.size_x) && (iy>0) && (iy<=map.size_y))
		draw_point(ix, iy, 2, 3);

	ix=ppar.bx * map.scale;
	iy=map.size_y-(ppar.by * map.scale);
	if ((ix>0) && (ix<=map.size_x) && (iy>0) && (iy<=map.size_y))
		draw_point(ix, iy, 3, 3);


	refresh_screen();

	for (i=0; i<MAX_PARTICLES; i++)
		{
		ix=particle[i].x*map.scale;
		iy=map.size_y-(particle[i].y*map.scale);
		if ((ix<0) ||(ix>=map.size_x) || (iy<0) ||(iy>=map.size_y)) continue;
		if(map.grid[ix][iy]==-1) draw_point(ix, iy, 4, 1);
		}

	ix=ppar.mx * map.scale;
	iy=map.size_y-(ppar.my * map.scale);
	if ((ix>0) && (ix<=map.size_x) && (iy>0) && (iy<=map.size_y))
		draw_point(ix, iy, 4, 3);

	ix=ppar.bx * map.scale;
	iy=map.size_y-(ppar.by * map.scale);
	if ((ix>0) && (ix<=map.size_x) && (iy>0) && (iy<=map.size_y))
		draw_point(ix, iy, 4, 3);
	}



inline unsigned do_observation_model(float x, float y, float a)
	{
//	float mx, my;
	int i, res=0;
	int gx, gy;

	gx=(int) x*map.scale;
	gy=(int) map.size_y-(y*map.scale);

	if ((gx<0) || (gx>=map.size_x) || (gy<0) || (gy>=map.size_y))	return 0;

	if (map.grid[gx][gy]!=-1) return 0;

	for(i=0; i<181; i+=10)
			{
			gx=(x+laser->scan[i][0]*cos(a+laser->scan[i][1])) * map.scale;
			gy=map.size_y-((y+laser->scan[i][0]*sin(a+laser->scan[i][1])) * map.scale);

			if ((gx<0) || (gx>=map.size_x) || (gy<0) || (gy>=map.size_y)) continue;

			if ((laser->scan[i][0]>7.98) && (map.grid[gx][gy]==-1))	res+=2;
			else																										res+=map.lh_grid[gx][gy];
			}

	return res/10;
//	return 100;
	}


inline float round_angle(float a)
	{

	while (a >  3.14159265) a -= 6.2831853;
	while (a < -3.14159265) a += 6.2831853;

	return a;
	}

float normal(float sd)
	{
	int i;
	float num;

	num=0;
	for(i=0;i<12;i++)
  	num+=(rand()/(RAND_MAX/2.0))-1;
	//	num+=(rand()/(RAND_MAX/1.0));

	num=num*sd/6;
	return num;
	}

inline void do_action_model2(float rot1, float rot2, float trn, float xo, float yo, float to, float *xr, float *yr, float *tr)
	{
	float rot1b, trnb, rot2b;
	float cr1=0.5, cr2=0.3, ct1=0.25, ct2=0.6, sd_t=1.0, sd_r=0.6;
	float n1, n2;

	n1=normal(sd_t);
//	n2=normal(sd_r);
	n2=n1*0.8;
		
	rot1b	 = rot1 + ct1 * n1*trn + cr1 * n2*rot1;
	rot2b	 = rot2 + ct1 * n1*trn + cr1 * n2*rot2;
	trnb   = trn  + ct2 *  n1*trn + cr2 * n2*(rot1+rot2);

/*	rot1b	 = rot1;
	rot2b	 = rot2;
	trnb   = trn;*/

	*xr = xo + trnb * cos(rot1b+to);
	*yr = yo + (trnb * sin(rot1b+to));
	*tr = to + (rot1b + rot2b);
	}

inline void resample_one(int i)
	{
	int ref;

	ref=rand()%MAX_PARTICLES;

	while (map.grid[(int) (particle[ref].x*map.scale)][(int) (map.size_y-(particle[ref].y*map.scale))] != -1)
		{
		ref=rand()%MAX_PARTICLES;
		}


	particle[i].x = particle[ref].x;
	particle[i].y = particle[ref].y;
	particle[i].a = particle[ref].a;
	}


inline void resample_all(unsigned total, float res_rate)
	{
	int i;
	long aux2, r, j, max_j, min_j, old_j;
	float rx, ry, ra, rms;

	for(i=0; i< (int) MAX_PARTICLES*res_rate; i++)
		{
		r=(long) (rand()%(total));

		j=MAX_PARTICLES/2;
		max_j=(MAX_PARTICLES-1);
		min_j=0;

		while (1)
			{
			if ((j>0) && (j<(MAX_PARTICLES-1)))
				{
				if ((particle[j-1].accw < r) && (particle[j].accw >= r)) break;
				}
			else break;

			if (particle[j].accw < r)
				{
				min_j=j;
				old_j=j;
				j=(min_j+max_j)/2;
				if (j==old_j)
					{
					min_j++;
					j++;
					}
				}
			else
				{
				max_j=j;
				old_j=j;
				j=(min_j+max_j)/2;
				if (j==old_j)
					{
					max_j--;
					j--;
					}
				}
			}

		particle[i].x=particle[j].x;
		particle[i].y=particle[j].y;
		particle[i].a=particle[j].a;
		}

	for(i= (int) MAX_PARTICLES*res_rate; i<MAX_PARTICLES; i++)
		{
		rand_position(&rx, &ry, &ra);

		particle[i].x=rx;
		particle[i].y=ry;
		particle[i].a=ra;
		}
	}


void calc_mean()
	{
	register int i;
	float best_x=0, best_y=0, best_a=0, best_score=0;
	int conv_flag;
	float conv_thold=0.4;
	int ix, iy;
	int invalid=0;

	double mean_sin=0, mean_cos=0;

	for (i=0;i<MAX_PARTICLES;i++)
		{
		if (map.grid[(int) (particle[i].x*map.scale)][(int) (map.size_y-(particle[i].y*map.scale))] != -1)
			{
			particle[i].valid=0;
			invalid++;
			}
		else	particle[i].valid=1;
		}

	if (invalid > 0) printf("\n***** Invalid:%i ********\n", invalid);

	for (i=0;i<MAX_PARTICLES;i++)
	if (particle[i].valid)
		{
		mean_x+=particle[i].x;
		mean_y+=particle[i].y;

		mean_sin += sin(particle[i].a);
		mean_cos += cos(particle[i].a);

		if (particle[i].w > best_score)		
			{
			best_score = particle[i].w;
			best_x = particle[i].x;
			best_y = particle[i].y;
			best_a = particle[i].a;
			}
		}


	mean_x/=(MAX_PARTICLES-invalid);
	mean_y/=(MAX_PARTICLES-invalid);

	mean_sin/=(MAX_PARTICLES-invalid);
	mean_cos/=(MAX_PARTICLES-invalid);

	mean_a=atan2(mean_sin, mean_cos);

	for (i=0;i<MAX_PARTICLES;i++)
	if (particle[i].valid)
		{
		stdev_x+=fabsf(particle[i].x-mean_x);
		stdev_y+=fabsf(particle[i].y-mean_y);
		}

	stdev_x/=(MAX_PARTICLES-invalid);
	stdev_y/=(MAX_PARTICLES-invalid);

	fprintf(locFile,"\r%d %.2lf %.2lf %.2lf", 1, mean_x,  mean_y, mean_a*57.3);
//	printf("\rMean x:%.2lf , y:%.2lf , a:%.2lf StdDev x:%.2lf, y:%.2lf", mean_x,  mean_y, mean_a*57.3,  stdev_x, stdev_y);

        n = sprintf(out, "%.2lf %.2lf %.2lf ", mean_x, mean_y, mean_a*57.3);

	ppar.mx = mean_x;
	ppar.my = mean_y;
	ppar.bx = best_x;
	ppar.by = best_y;
	}

void filter_loop(void)
	{
	float xn, yn, an;
	float xo, yo, ao;
	float rot1, rot2, trn;
	float dif_x, dif_y, dif_a;
	int i, count=0, invalid;
	unsigned obs_res, obs_total;
	unsigned longt_total=0, shortt_total=0;
	float resample_rate;

	struct timeval time1, time2;
	long unsigned timed;

	int skip_print=5;
	int skip_obs  =10;

	g_print("\nEntering loop\n");	

	for(i=0; i<10; i++)	
		playerc_client_read(client);

	xo = position->px;
	yo = position->py;
	ao = position->pa;

//	draw_point(210, 190, 1, 3);	

	while(1)	
		{
		calc_mean();

		count++;

		playerc_client_read(client);
		playerc_client_read(client);
		playerc_client_read(client);
		playerc_client_read(client);
		playerc_client_read(client);

		dif_x = position->px - xo;
		dif_y = position->py - yo;
		dif_a = position->pa - ao;

		if ((int)(dif_x*1000) || (int)(dif_y*1000) || (int)(dif_a*1000))
			{
			rot1 = atan2(dif_y,dif_x)-ao;
			rot2 = dif_a-rot1;
			trn   = sqrt((dif_x*dif_x)+(dif_y*dif_y));

			xo = position->px;
			yo = position->py;
			ao = position->pa;

			rot1=round_angle(rot1);
			rot2=round_angle(rot2);

			invalid=0;

			for (i=0; i < MAX_PARTICLES; i++)
				{
				do_action_model2(rot1, rot2, trn, particle[i].x, particle[i].y, particle[i].a, &particle[i].x, &particle[i].y, &particle[i].a);
		
				if (map.grid[(int) (particle[i].x*map.scale)][(int) (map.size_y-(particle[i].y*map.scale))] != -1)
					{	
					resample_one(i);
					invalid++;
					}
	
				particle[i].a = round_angle(particle[i].a);
				}


			if ((count % skip_print)==0)	
				{
				print_particles();
				}

			if ((count % skip_obs)==0)	
				{
				obs_total=0;

				for (i=0; i < MAX_PARTICLES; i++)
					{
					particle[i].w = do_observation_model(particle[i].x, particle[i].y, particle[i].a);
					obs_total += particle[i].w;
					particle[i].accw = obs_total;
					}

				longt_total =  (longt_total *0.90) + (obs_total*0.10);
				shortt_total = (shortt_total*0.60) + (obs_total*0.40);

				resample_rate = (float) (shortt_total/ (1.0*longt_total));

				printf("\nlt:%u, st:%u, s/l:%.2f (%i)\n", longt_total, shortt_total, resample_rate, invalid);

				if (invalid > (MAX_PARTICLES*0.1)) resample_rate=0.80;
				else if (resample_rate < 0.30)     resample_rate=0.75;
				else											         resample_rate=1.00;

				resample_all(obs_total, resample_rate);
				}
			}
		}
	}



void *server(void* mes)
{
     printf("\nServer running...\n");

     int sockfd, newsockfd, portno, clilen;
     char buffer[256];

     struct sockaddr_in serv_addr, cli_addr;

     sockfd = socket(AF_INET, SOCK_STREAM, 0);
     if (sockfd < 0) 
        perror("ERROR opening socket");
     bzero((char *) &serv_addr, sizeof(serv_addr));
     portno = 50000;
     serv_addr.sin_family = AF_INET;
     serv_addr.sin_addr.s_addr = INADDR_ANY;
     serv_addr.sin_port = htons(portno);
     if (bind(sockfd, (struct sockaddr *) &serv_addr,
              sizeof(serv_addr)) < 0) 
              error("ERROR on binding");

     while(1)
     {		
     listen(sockfd,5);
     clilen = sizeof(cli_addr);
     newsockfd = accept(sockfd, 
                 (struct sockaddr *) &cli_addr, 
                 &clilen);
     if (newsockfd < 0) 
          error("ERROR on accept");
//     bzero(buffer,256);
//     n = read(newsockfd,buffer,255);
//     if (n < 0) error("ERROR reading from socket");
//     n = sprintf(out, "%.2lf %.2lf %.2lf ", mean_x, mean_y, mean_a*57.3);


     n = write(newsockfd,out,n);
     printf("\nSent location of: %s\n",out);
     if (n < 0) error("ERROR writing to socket");
     
     
     
     }
     
     close(sockfd);
     
}



void run_pf(void)
	{
	int i;

	struct timeval time;

	gettimeofday(&time, NULL);

	srand(time.tv_usec);

    locFile=fopen("pf_loc/src/localization","w");
    if (locFile==NULL){
        printf("\nFile Error\nTrying to open:'%s'\n","localization");
        exit(1);
    }

	if (gui)	
		clear_screen();

	load_map("rth.map");	map.scale=10;

	if (gui)	
		print_map();

	calc_lh_map();
//	print_lh_map();

//	init_particles();
	init_particles2(11.87, 3.09, 0);

	
//	client = playerc_client_create(NULL, "localhost", 6665);
	client = playerc_client_create(NULL, "100.0.0.38", 6665);
	if (playerc_client_connect(client) != 0) printf("\nError: Init Player");

	position = playerc_position_create(client, 0);
	if (playerc_position_subscribe(position, PLAYER_ALL_MODE))
	  	printf("\nError: Init Player");

	if (playerc_position_enable(position, 1) != 0)
 	printf("\nError: Init Player");

	laser = playerc_laser_create(client, 0);
	if (playerc_laser_subscribe(laser, PLAYER_READ_MODE))
	  	printf("\nError: Init Player");

//        if (playerc_position_set_cmd_pose(position, 11.87, 3.09, 0.0, 0))
//	  	printf("\nError: Setting Position");

	if (gui)	
		{
		print_map();
		print_particles();
		}

	//  int iret;
	//  pthread_t serverThread;
	//  iret = pthread_create(&(serverThread), NULL, server, (void*) "");

	filter_loop();
	}

