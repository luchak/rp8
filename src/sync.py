import random
import subprocess

if __name__=='__main__':
    # Start a new process
    p = subprocess.Popen(['pico8','-run', '/Users/matt/workspace/pico-8/rp8/src/rp8.p8'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    while p.poll()==None:
        p.stdout.readline()
        # print(random.randint(129,131))
        p.stdin.write(str(random.randint(128,132))+'\n')
        p.stdin.flush()

    # Close the process
    p.stdin.close()
    p.wait()

