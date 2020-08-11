#include <gtk/gtk.h>

#include "draw.h"

#define MAP_ZOOM 2

GdkColor color;

void draw_point(int x, int y, int col, int size)
{

x *= MAP_ZOOM;
y *= MAP_ZOOM;
size *= MAP_ZOOM;

if ((x<0) || (x>=700) || (y<0) || (y>=500))
	{
//	g_print("d");
//	g_print("\nERROR: Drawing out of limits (%i, %i)", x, y);
	return;
	}

//g_print("\nDraw x:%i y:%i", x, y);

if(col==0)
	{
  color.red  =0;
  color.green=0;
  color.blue =0;
	}
else 	if(col==1)
	{
  color.red  =65535;
  color.green=10000;
  color.blue =10000;
	}
else 	if(col==2)
	{
	color.red  =20000;
  color.green=65535;
  color.blue =20000;
	}
else 	if(col==3)
	{
	color.red  =20000;
  color.green=20000;
  color.blue =65535;
	}
else 	if(col==4)
	{
	color.red  =65535;
  color.green=65535;
  color.blue =65535;
	}
else 	if(col==10)
	{
	color.red  =35000;
  color.green=35000;
  color.blue =35000;
	}
else 	if(col==11)
	{
	color.red  =40000;
  color.green=40000;
  color.blue =40000;
	}
else 	if(col==12)
	{
	color.red  =45000;
  color.green=45000;
  color.blue =45000;
	}
else 	if(col==13)
	{
	color.red  =50000;
  color.green=50000;
  color.blue =50000;
	}
else 	if(col==14)
	{
	color.red  =55000;
  color.green=55000;
  color.blue =55000;
	}
else 	if(col==15)
	{
	color.red  =60000;
  color.green=60000;
  color.blue =60000;
	}


	gdk_gc_set_rgb_fg_color (gcont, &color);
	gdk_draw_rectangle(pixmap, gcont, TRUE, x, y, size, size);
}


void clear_screen()
{
  color.red  =65535;
  color.green=65535;
  color.blue =65535;

	gdk_gc_set_rgb_fg_color (gcont, &color);
	gdk_draw_rectangle(pixmap, gcont, TRUE, 0, 0, 700, 500);
}
