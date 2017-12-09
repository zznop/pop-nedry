import sys
import subprocess
import argparse
import os

def fixup_bin(url):
    """Overwrite the URL placeholder with the user's supplied URL
    """
    f = open('build\\pop-nedry.bin', 'r+b')
    f.seek(0x1dd)
    f.write(url)
    f.close()

def build_binary():
    """Compile the assembly and build a standalone bin
    """
    if not os.path.exists('.\\build'):
        os.makedirs('.\\build')

    os.chdir('.\\src')
    subprocess.check_call([
        'nasm.exe', '-f', 'bin', '-o',
        '..\\build\\pop-nedry.bin', 'pop-nedry.asm'
    ])
    os.chdir('..\\')

def parse_args():
    """Parse command line arguments
    """
    parser = argparse.ArgumentParser(
        description="pop-nedry Win64 shellcode build script"
    )

    parser.add_argument(
        '--url', type=str, required=True,
        help='URL for web page hosting the Nedry GIF'
    )

    return parser.parse_args()

def main():
    """Run the script
    """
    args = parse_args()
    args.url = args.url.lower()
    if not args.url.startswith('http://') and not args.url.startswith('https://'):
        print "! your URL must start with http:// or https://"
        sys.exit(1)

    build_binary()
    fixup_bin(args.url)

if __name__ == '__main__':
    main()