import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from cultist_model import specification
globals().update(specification('forest_explorer',os.path.dirname(os.path.abspath(__file__)),False))
if __name__=='__main__':run(globals())
