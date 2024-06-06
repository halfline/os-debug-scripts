#!/usr/bin/python3

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

class MyApplication(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.redhat.FocusTheftCrimes")
        self.main_window = None
        self.transient_window = None

    def do_activate(self):
        self.main_window = Gtk.ApplicationWindow(application=self)
        self.main_window.set_title("Main Window")
        self.main_window.set_default_size(300, 200)
        self.main_window.show_all()

        GLib.timeout_add_seconds(10, self.show_transient_window)

    def show_transient_window(self):
        self.transient_window = Gtk.Window(transient_for=self.main_window, modal=True)
        self.transient_window.set_title("Transient Window")
        self.transient_window.set_default_size(200, 150)
        self.transient_window.show_all()
        return False

app = MyApplication()
app.run(None)

