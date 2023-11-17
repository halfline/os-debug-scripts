#include <gtk/gtk.h>

static gboolean
on_enter_notify_event(GtkWidget *widget,
                      GdkEventCrossing *event,
                      gpointer data)
{
    gdk_seat_grab(gdk_display_get_default_seat(gdk_display_get_default()),
                  gtk_widget_get_window(widget),
                  GDK_SEAT_CAPABILITY_KEYBOARD | GDK_SEAT_CAPABILITY_ALL_POINTING,
                  FALSE, NULL, NULL, NULL, NULL);
    return TRUE;
}

static gboolean
on_leave_notify_event(GtkWidget *widget,
                      GdkEventCrossing *event,
                      gpointer data)
{
    gdk_seat_ungrab(gdk_display_get_default_seat(gdk_display_get_default()));
    return TRUE;
}

static gboolean on_focus_out_event(GtkWidget *widget,
                                   GdkEventFocus *event,
                                   gpointer data)
{
    gdk_seat_ungrab(gdk_display_get_default_seat(gdk_display_get_default()));
    return TRUE;
j

int main(int argc,
         char *argv[])
{
    gtk_init(&argc, &argv);

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Virtual Machine");
    gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);

    g_signal_connect(window, "enter-notify-event", G_CALLBACK(on_enter_notify_event), NULL);
    g_signal_connect(window, "leave-notify-event", G_CALLBACK(on_leave_notify_event), NULL);
    g_signal_connect(window, "focus-out-event", G_CALLBACK(on_focus_out_event), NULL);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    gtk_widget_set_events(window, GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK | GDK_FOCUS_CHANGE_MASK);
    gtk_widget_show_all(window);

    gtk_main();
    return 0;
}

