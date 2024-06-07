/* gcc find-best-user-time-to-forge.c -lX11 -o find-best-user-time-to-forge */
#include <stdio.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

static Atom _NET_WM_USER_TIME;

unsigned long
get_window_user_time (Display *display,
                      Window   window)
{
        Atom actual_type;
        int actual_format;
        unsigned long nitems;
        unsigned long bytes_after;
        unsigned char *prop = NULL;
        unsigned long user_time = 0;

        if (XGetWindowProperty (display,
                                window,
                                _NET_WM_USER_TIME,
                                0,
                                1,
                                False,
                                XA_CARDINAL,
                                &actual_type,
                                &actual_format,
                                &nitems,
                                &bytes_after,
                                &prop) == Success && prop) {
                if (nitems == 1) {
                        user_time = *((unsigned long *) prop);
                }
                XFree (prop);
        }

        return user_time;
}

void
find_latest_user_time (Display       *display,
                       Window         root,
                       unsigned long *latest_time)
{
        Window root_return;
        Window parent_return;
        Window *children;
        unsigned int number_of_children;
        unsigned long user_time;

        if (XQueryTree (display, root, &root_return, &parent_return, &children, &number_of_children)) {
                for (unsigned int i = 0; i < number_of_children; i++) {
                        user_time = get_window_user_time (display, children[i]);
                        if (user_time > *latest_time) {
                                *latest_time = user_time;
                        }
                        find_latest_user_time (display, children[i], latest_time);
                }

                XFree (children);
        }
}

int
main (void)
{
        Display *display;
        Window root;
        unsigned long latest_time = 0;

        display = XOpenDisplay (NULL);
        if (!display) {
                fprintf (stderr, "Unable to open display\n");
                return 1;
        }

        _NET_WM_USER_TIME = XInternAtom (display, "_NET_WM_USER_TIME", True);
        if (_NET_WM_USER_TIME == None) {
                fprintf (stderr, "_NET_WM_USER_TIME atom not available\n");
                XCloseDisplay (display);
                return 1;
        }

        root = DefaultRootWindow (display);
        find_latest_user_time (display, root, &latest_time);

        printf ("%lu\n", latest_time);

        XCloseDisplay (display);
        return 0;
}
