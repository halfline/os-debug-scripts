#include <cstring>
#include <iostream>
#include <vector>
#include <string>
#include <dbus/dbus.h>

class LoginManager
{
public:
    LoginManager ();
    ~LoginManager ();
    bool hasSession (const std::string& username);

private:
    bool checkSessionForUser (const std::string& objectPath, const std::string& username);
    DBusConnection* conn;
    DBusError err;
};

LoginManager::LoginManager ()
{
    dbus_error_init (&err);
    conn = dbus_bus_get (DBUS_BUS_SYSTEM, &err);
    if (dbus_error_is_set (&err)) {
        std::cerr << "error: " << err.message << "." << std::endl;
        dbus_error_free (&err);
        exit (EXIT_FAILURE);
    }
}

LoginManager::~LoginManager ()
{
    dbus_connection_unref (conn);
}

bool LoginManager::hasSession (const std::string& username)
{
    DBusMessage* msg;
    DBusMessage* reply;
    DBusMessageIter args, sub, subsub;

    msg = dbus_message_new_method_call ("org.freedesktop.login1",
                                       "/org/freedesktop/login1",
                                       "org.freedesktop.login1.Manager",
                                       "ListSessions");

    reply = dbus_connection_send_with_reply_and_block (conn, msg, -1, &err);
    dbus_message_unref (msg);
    if (dbus_error_is_set (&err)) {
        std::cerr << "error: " << err.message << "." << std::endl;
        dbus_error_free (&err);
        return false;
    }

    bool sessionFound = false;
    dbus_message_iter_init (reply, &args);
    if (dbus_message_iter_get_arg_type (&args) != DBUS_TYPE_ARRAY) {
        std::cerr << "Argument is not an array" << std::endl;
    } else {
        dbus_message_iter_recurse (&args, &sub);
        while (dbus_message_iter_get_arg_type (&sub) != DBUS_TYPE_INVALID) {
            dbus_message_iter_recurse (&sub, &subsub);
            while (dbus_message_iter_get_arg_type (&subsub) != DBUS_TYPE_INVALID) {
                if (dbus_message_iter_get_arg_type (&subsub) == DBUS_TYPE_OBJECT_PATH) {
                    const char* object_path;
                    dbus_message_iter_get_basic (&subsub, &object_path);
                    if (object_path != nullptr && checkSessionForUser (object_path, username)) {
                        sessionFound = true;
                        break;
                    }
                }
                dbus_message_iter_next (&subsub);
            }
            if (sessionFound) break;
            dbus_message_iter_next (&sub);
        }
    }

    dbus_message_unref (reply);
    return sessionFound;
}

bool LoginManager::checkSessionForUser (const std::string& objectPath, const std::string& username)
{
    DBusMessage* msg;
    DBusMessage* reply;
    DBusMessageIter args;

    msg = dbus_message_new_method_call ("org.freedesktop.login1",
                                       objectPath.c_str (),
                                       "org.freedesktop.DBus.Properties",
                                       "GetAll");

    const char* interface_name = "org.freedesktop.login1.Session";
    dbus_message_append_args (msg, DBUS_TYPE_STRING, &interface_name, DBUS_TYPE_INVALID);

    reply = dbus_connection_send_with_reply_and_block (conn, msg, -1, &err);
    dbus_message_unref (msg);
    if (dbus_error_is_set (&err)) {
        std::cerr << "error: " << err.message << "." << std::endl;
        dbus_error_free (&err);
        return false;
    }

    bool userMatches = false;
    bool isGraphical = false;
    dbus_message_iter_init (reply, &args);
    if (dbus_message_iter_get_arg_type (&args) != DBUS_TYPE_ARRAY) {
        std::cerr << "Argument is not an array" << std::endl;
    } else {
        DBusMessageIter dict;
        dbus_message_iter_recurse (&args, &dict);
        while (dbus_message_iter_get_arg_type (&dict) != DBUS_TYPE_INVALID) {
            DBusMessageIter entry;
            dbus_message_iter_recurse (&dict, &entry);
            const char* key;
            dbus_message_iter_get_basic (&entry, &key);
            dbus_message_iter_next (&entry);
            if (strcmp (key, "Name") == 0) {
                DBusMessageIter variant;
                dbus_message_iter_recurse (&entry, &variant);
                const char* value;
                if (dbus_message_iter_get_arg_type (&variant) == DBUS_TYPE_STRING) {
                    dbus_message_iter_get_basic (&variant, &value);
                    if (value == username) {
                        userMatches = true;
                    }
                }
            } else if (strcmp (key, "Type") == 0) {
                DBusMessageIter variant;
                dbus_message_iter_recurse (&entry, &variant);
                const char* value;
                if (dbus_message_iter_get_arg_type (&variant) == DBUS_TYPE_STRING) {
                    dbus_message_iter_get_basic (&variant, &value);
                    if (strcmp (value, "x11") == 0 || strcmp (value, "wayland") == 0) {
                        isGraphical = true;
                    }
                }
            }
            dbus_message_iter_next (&dict);
        }
    }

    dbus_message_unref (reply);
    return userMatches && isGraphical;
}

int main (int argc, char* argv[])
{
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <username>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string username = argv[1];
    LoginManager manager;
    if (manager.hasSession (username)) {
        std::cout << "User " << username << " has an active session." << std::endl;
    } else {
        std::cout << "User " << username << " does not have an active session." << std::endl;
    }

    return EXIT_SUCCESS;
}

