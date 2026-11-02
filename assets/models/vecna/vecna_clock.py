import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from companions import make
globals().update(make("vecna_clock",os.path.dirname(os.path.abspath(__file__))))
if __name__=='__main__':run(globals())
