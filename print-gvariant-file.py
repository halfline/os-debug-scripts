#!/usr/bin/python3
import gi
import argparse
import os
import sys
from gi.repository import GLib

def load_variant(file_path, type):
    try:
        with open(file_path, 'rb') as f:
            data = f.read()
        variant = GLib.Variant.new_from_bytes(GLib.VariantType(type), GLib.Bytes.new(data), False)
        return variant
    except Exception as e:
        print(f"Failed to load data as type '{type}': {e}", file=sys.stderr)
        return None

def determine_type(file_path):
    filename = os.path.basename(file_path)
    if filename == "notifications":
        return "a(sa(sv))"
    elif filename == "screenShield.locked":
        return "b"
    else:
        return None

def print_variant(variant):
    if variant is not None:
        print(variant.print_(True))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Dump the contents of a GVariant state file.')
    parser.add_argument('file_path', type=str, help='Path to the state file.')
    parser.add_argument('--type', type=str, help='The GVariant type.')

    args = parser.parse_args()
    type = args.type

    if not type:
        type = determine_type(args.file_path)

    if type:
        variant = load_variant(args.file_path, type)
        print_variant(variant)
    else:
        print("Error: Type of GVariant file unknown, please specify with --type.", file=sys.stderr)

