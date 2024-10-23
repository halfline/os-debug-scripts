#!/usr/bin/python
import gi
from gi.repository import GLib, Gtk

GLib.log_set_handler(None, GLib.LogLevelFlags.LEVEL_MASK, lambda *args: None, None)
GLib.log_set_writer_func(lambda *args: GLib.LogWriterOutput.HANDLED, None)

def log(log_level, message):
    log_data = GLib.Variant('a{sv}', {"MESSAGE": GLib.Variant('s', message)})

    GLib.log_variant("test-app", log_level, log_data)

def trigger_log_messages():
    log(GLib.LogLevelFlags.LEVEL_INFO, "This is an informational message.")
    log(GLib.LogLevelFlags.LEVEL_WARNING, "This is a warning message.")
    log(GLib.LogLevelFlags.LEVEL_CRITICAL, "This is a critical message.")
    log(GLib.LogLevelFlags.LEVEL_ERROR, "This is an error message. bye bye")


def on_button_clicked(button):
    print("Button clicked, triggering log messages...")
    trigger_log_messages()

window = Gtk.Window()

button = Gtk.Button(label="Click Me")
button.connect("clicked", on_button_clicked)
window.set_child(button)
window.present()

event_loop = GLib.MainLoop()
window.connect("destroy", event_loop.quit)
event_loop.run()


