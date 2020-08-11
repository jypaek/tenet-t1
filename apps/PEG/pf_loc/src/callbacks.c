#ifdef HAVE_CONFIG_H
#  include <config.h>
#endif

#include <gtk/gtk.h>

#include "callbacks.h"
#include "interface.h"
#include "support.h"

#include <pthread.h>

#include "draw.h"
#include "run.h"

GdkGC *gcont;
GdkPixmap *pixmap;
GtkWidget *darea;
//GdkColor color;

void
on_button1_clicked                     (GtkButton       *button,
                                        gpointer         user_data)
{
	pthread_t thread1;

	darea= lookup_widget(GTK_WIDGET(button), "drawingarea1");
	gcont = gdk_gc_new(darea->window);
	pixmap=gdk_pixmap_new(darea->window, 800, 600, -1);

	pthread_create(&thread1, NULL, (void *)&run_pf, NULL);
	g_print("\nRunning!");
}


void
on_button3_clicked                     (GtkButton       *button,
                                        gpointer         user_data)
{

}


void
on_button2_clicked                     (GtkButton       *button,
                                        gpointer         user_data)
{
g_print("\n");
gtk_exit(0);
}

