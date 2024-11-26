#!/usr/bin/python3
import argparse
from transformers import AutoTokenizer

def main():
    parser = argparse.ArgumentParser(
        description="Load a tokenizer from a model and print its vocabulary."
    )
    parser.add_argument(
        "--model",
        type=str,
        default="ibm-granite/granite-3.0-8b-instruct",
        help="Name or path of the model to load the tokenizer from."
    )
    args = parser.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(args.model, use_fast=False)

    vocabulary = tokenizer.get_vocab()

    for token, index in vocabulary.items():
        print(f"{index} {token}")

if __name__ == "__main__":
    main()

