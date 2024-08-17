import mistune
import argparse

class MarkdownEvaluator(mistune.HTMLRenderer):
    def __init__(self):
        super().__init__()
        self.headings = []

    def heading(self, text, level):
        self.headings.append({
            'text': text,
            'level': level
        })
        return super().heading(text, level)

class MarkdownRenderer(mistune.HTMLRenderer):
    def __init__(self, strip_links=False, headings=None):
        super().__init__()
        self.strip_links = strip_links
        self.headings = headings if headings is not None else []

    def block_code(self, code, info=None):
        return f"\n```\n{code}```\n"

    def block_error(self, text):
        return f"\n! {text}\n"

    def block_html(self, html):
        return f"\n| {text}\n"

    def block_quote(self, text):
        return f"\n> {text}\n"

    def block_text(self, text):
        return f"\n| {text}\n"

    def codespan(self, text):
        return f"`{text}`"

    def emphasis(self, text):
        return f"*{text}*"

    def heading(self, text, level):
        if level == 1:
            underline = '=' * len(text)
            return f"\n{text}\n{underline}\n"
        else:
            underline = '-' * len(text)
            return f"\n{text}\n{underline}\n"

    def image(self, src, alt="", title=None):
        return f"[Image: {alt}]"

    def inline_html(self, html):
        return f"`{html}`"

    def linebreak(self):
        return "\n"

    def table_of_contents(self):
        table_of_contents = []
        for heading in self.headings:
            indent = '  ' * (heading['level'] - 1)
            table_of_contents.append(f"{indent}- {heading['text']}")
        return '\n'.join(table_of_contents)

    def link(self, text, url, title):
        if self.strip_links:
            return text
        else:
            return f"{text} <{url}>"

    def list(self, body, ordered, level, start):
        indent = '  ' * (level - 1)
        indented_body = ''.join([f"{indent}{line}" for line in body.splitlines(True)])
        return f"{indented_body}\n"

    def list_item(self, text, level):
        indent = '  ' * (level - 1)
        prefix = f"{indent}- " if level == 1 else f"{indent}* "
        return f"{prefix}{text}\n"

    def paragraph(self, text):
        if text.strip() == '[[*TOC*]]':
            return f"{self.table_of_contents()}\n\n"
        return f"{text}\n\n"

    def strong(self, text):
        return f"**{text}**"

    def text(self, text):
        return text

    def thematic_break(self):
        return "\n---\n"

def process_markdown(filename, strip_links_flag):
    evaluator = MarkdownEvaluator()
    evaluation_pass = mistune.create_markdown(renderer=evaluator)

    try:
        with open(filename, 'r') as file:
            markdown_input = file.read()

            evaluation_pass(markdown_input)

            renderer = MarkdownRenderer(strip_links=strip_links_flag, headings=evaluator.headings)
            renderer_pass = mistune.create_markdown(renderer=renderer)

            result = renderer_pass(markdown_input)
            print(result)

    except FileNotFoundError:
        print(f"Error: The file '{filename}' was not found.")
        exit(1)

def main():
    parser = argparse.ArgumentParser(description="Process a Markdown file with optional link stripping.")
    parser.add_argument("filename", help="The Markdown file to process")
    parser.add_argument("--strip-links", action="store_true", help="Strip links from the Markdown file, preserving link text")

    args = parser.parse_args()

    process_markdown(args.filename, args.strip_links)

if __name__ == "__main__":
    main()

