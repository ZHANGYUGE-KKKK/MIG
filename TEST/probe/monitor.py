#!/usr/bin/env python3
"""Receive-only capture and strict decoder for ddr3_probe records (all raw fields hex)."""
import argparse,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PORT='/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0'

def expected_config(j):
    if j<24:return (0,j//4,1,10000,1,1,64,0,0,0,j%4)
    if j<48:return (1,(j-24)//6,3,30000,1,1,64,0,((j-24)//2)%3,(j-24)%2,0)
    n=j-48
    return (2,(4+n//108) if n<216 else 0,65536,65536,1<<((n//18)%6),1 if (n//9)%2==0 else 32,
            (0,16,64)[(n//3)%3],(0,16,64)[n%3],0,0,0)

def decode(path):
    jobs={};done=None;fatal=None;bad=[];total_bits=[0]*128
    for number,line in enumerate(path.read_text(errors='replace').splitlines(),1):
        if not line.startswith('D '):continue
        try:
            words=line.split()[1:]
            assert len(words)==8 and all(len(w)==16 for w in words)
            f=[int(w,16) for w in words];kind=f[0]>>32;j=f[0]&0xffffffff
            if kind==1:
                assert j not in jobs
                jobs[j]={'stage':f[1],'pattern':f[2],'expected_writes':f[3],'expected_reads':f[4],
                         'read_limit':f[5],'write_limit':f[6],
                         'turn_gap':f[7]>>56,'read_gap':(f[7]>>48)&255,
                         'rotation':(f[7]>>40)&255,'reverse':(f[7]>>32)&255,'target':f[7]&0xffffffff,
                         'samples':[],'bit_flips':{}}
                d=jobs[j]
                actual=tuple(d[k] for k in ('stage','pattern','expected_writes','expected_reads','read_limit','write_limit','turn_gap','read_gap','rotation','reverse','target'))
                assert actual==expected_config(j), 'configuration mismatch'
            elif kind==2:
                d=jobs[j];assert 'reads' not in d
                d.update(write_commands=f[1],write_data=f[2],read_commands=f[3],reads=f[4],errors=f[5],changed_from_first=f[6])
                assert f[1]==f[2]==d['expected_writes'] and f[3]==f[4]==d['expected_reads']
            elif kind==3:
                d=jobs[j];exp=(f[2]<<64)|f[3];got=(f[4]<<64)|f[5];assert exp!=got
                d['samples'].append({'native_addr':f[1],'byte_base':f[1]*2,'read_index':f[6],
                                     'expected':f'{exp:032X}','actual':f'{got:032X}','xor':f'{exp^got:032X}'})
            elif kind==4:
                assert 0<=f[1]<128 and f[2]>0 and f[1] not in jobs[j]['bit_flips']
                jobs[j]['bit_flips'][f[1]]=f[2];total_bits[f[1]]+=f[2]
            elif kind==5:
                done={'last_job':j,'errors':f[1]};break
            elif kind==6:
                fatal={'job':j,'code':f[1],'write_commands':f[3],'write_data':f[4],
                       'read_commands':f[5],'reads':f[6],'total_errors':f[7]};break
            else:raise ValueError('unknown kind')
        except (AssertionError,ValueError,KeyError) as e:bad.append({'line':number,'reason':str(e),'text':line})
    complete=done is not None and fatal is None and not bad and set(jobs)==set(range(372))
    if complete:
        complete=all('reads' in d and (d['errors']==0 or d['bit_flips']) and len(d['samples'])==min(4,d['errors']) for d in jobs.values())
        complete=complete and sum(d['errors'] for d in jobs.values())==done['errors']
    dq=[0]*16;beat=[0]*8;lane=[0]*2
    for bit,count in enumerate(total_bits):
        byte=bit//64;time_beat=(bit%64)//8;pin=byte*8+bit%8
        dq[pin]+=count;beat[time_beat]+=count;lane[byte]+=count
    return {'complete':bool(complete),'data_pass':bool(complete and done['errors']==0),
            'done':done,'fatal':fatal,'malformed':bad,'jobs':jobs,
            'ui_bit_flips':total_bits,'dq_bit_flips':dq,'beat_bit_flips':beat,'lane_bit_flips':lane}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--decode',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'TEST/probe/build/hardware_uart.log')
    parser.add_argument('--timeout',type=float,default=900)
    args=parser.parse_args()
    if args.decode:path=args.decode
    else:
        import serial
        busy=subprocess.run(['fuser',PORT],capture_output=True,text=True)
        if busy.returncode==0:raise SystemExit('UART busy; close terminal first. PIDs: '+busy.stdout.strip())
        path=args.output;path.parent.mkdir(parents=True,exist_ok=True)
        s=serial.Serial(port=None,baudrate=115200,timeout=0.2,exclusive=True)
        s.port=PORT;s.dtr=False;s.rts=False;s.open()
        print('UART CAPTURE READY '+PORT,flush=True)
        buffer=b'';end=time.monotonic()+args.timeout;stop=False;last_print=0
        with path.open('wb') as out:
            while time.monotonic()<end and not stop:
                try:
                    data=s.read(4096)
                except (serial.SerialException,OSError):
                    s.close();buffer=b''
                    print('UART disconnected; waiting for stable device path',flush=True)
                    while time.monotonic()<end:
                        try:
                            s.open();print('UART reconnected',flush=True);break
                        except (serial.SerialException,OSError):time.sleep(1)
                    else:break
                    continue
                if not data:continue
                out.write(data);out.flush();buffer+=data
                while b'\n' in buffer:
                    line,buffer=buffer.split(b'\n',1)
                    words=line.split()
                    if len(words)!=9 or words[0]!=b'D':continue
                    try:tag=int(words[1],16);kind=tag>>32;job=tag&0xffffffff
                    except ValueError:continue
                    if kind==2 and (time.monotonic()-last_print>5 or int(words[6],16)>0):
                        print('JOB',job,'errors',int(words[6],16),flush=True);last_print=time.monotonic()
                    if kind in (5,6):stop=True
        s.close()
    result=decode(path);summary=path.with_suffix('.json')
    summary.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('jobs','ui_bit_flips')},indent=2),flush=True)
    print('SAVED '+str(path)+' / '+str(summary),flush=True)
    return 0 if result['complete'] else 2
if __name__=='__main__':raise SystemExit(main())
