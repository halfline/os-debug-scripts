#!/usr/bin/python3
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
import sys
import subprocess

STATUS = {
    'available': 0,
    'invisible': 1,
    'busy': 2,
    'idle': 3
}

def presence_status_changed(status):
    """
    Callback function that gets called when the presence status changes.
    """
    if status == STATUS['idle']:
        subprocess.call(sys.argv[1:])

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    bus = dbus.SessionBus()

    presence = bus.get_object('org.gnome.SessionManager', '/org/gnome/SessionManager/Presence')

    presence.connect_to_signal('StatusChanged', presence_status_changed, dbus_interface='org.gnome.SessionManager.Presence')

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        loop.quit()

if __name__ == '__main__':
    main()

