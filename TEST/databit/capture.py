#!/usr/bin/env python3
"""Receive-only UART capture; refuse an already owned port. Start before DDR boot."""
import argparse,fcntl,os,select,shutil,subprocess,termios,time
from pathlib import Path
DEFAULT='/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0'
def main():
    p=argparse.ArgumentParser();p.add_argument('--port',default=DEFAULT);p.add_argument('--seconds',type=float,default=180);p.add_argument('--output',required=True);a=p.parse_args()
    port=Path(a.port).resolve(strict=True);output=Path(a.output)
    if output.exists():p.error('Output exists; use a new experiment filename')
    if not shutil.which('fuser'):p.error('fuser required for serial ownership check')
    owner=subprocess.run(['fuser',str(port)],capture_output=True,text=True)
    if owner.returncode==0:p.error(f'Serial port already in use: {owner.stdout.strip()}')
    if owner.returncode!=1:p.error(f'Cannot verify port ownership: {owner.stderr.strip()}')
    fd=os.open(port,os.O_RDWR|os.O_NOCTTY|os.O_NONBLOCK)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB);fcntl.ioctl(fd,termios.TIOCEXCL)
        saved=termios.tcgetattr(fd);cfg=termios.tcgetattr(fd)
        cfg[0]=0;cfg[1]=0;cfg[2]=termios.CS8|termios.CREAD|termios.CLOCAL;cfg[3]=0
        cfg[4]=termios.B115200;cfg[5]=termios.B115200;cfg[6][termios.VMIN]=0;cfg[6][termios.VTIME]=0
        termios.tcsetattr(fd,termios.TCSANOW,cfg)
        output.parent.mkdir(parents=True,exist_ok=True);total=0;tail=b'';terminal=False
        print(f'CAPTURE READY {port} 115200 8N1 -> {output}',flush=True)
        end=time.monotonic()+a.seconds
        with output.open('xb',buffering=0) as f:
            while time.monotonic()<end:
                if not select.select([fd],[],[],min(0.5,max(0,end-time.monotonic())))[0]:continue
                raw=os.read(fd,65536)
                if not raw:continue
                f.write(raw);total+=len(raw);tail=(tail+raw)[-65536:]
                if b'D 0000000500000000 ' in tail or b'D 0000000600000000 ' in tail:
                    # Wait for the complete terminal line, not just its prefix.
                    last=tail.rfind(b'D 0000000');terminal=b'\n' in tail[last:]
                    if terminal:break
            os.fsync(f.fileno())
        print(f'CAPTURE ENDED bytes={total} terminal_record={terminal}',flush=True)
        if not terminal:raise SystemExit(2)
    finally:
        if 'saved' in locals():termios.tcsetattr(fd,termios.TCSANOW,saved)
        os.close(fd)
if __name__=='__main__':main()
