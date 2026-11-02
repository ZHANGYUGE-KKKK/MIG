import csv,tempfile,unittest
from pathlib import Path
from decode_ila import decode

class DecoderTests(unittest.TestCase):
 def capture(self,errors=0,fatal=0,reads=1048576):
  fields=[(0x41584944,32),(9,32),(15,32),(fatal,32),(65536,32),(16,32),(65536,64),(reads,64),(errors,64),(65536,32),(65536,32),(100,32),(0x137a5c29,32)]
  summary=0
  for val,width in fields:summary=(summary<<width)|val
  first=(1<<290)|(144<<256)|(0<<128)|(1<<65) if errors else 0
  names=['test_engine_done','test_engine_debug_summary[511:0]','test_engine_debug_legs[511:0]','test_engine_debug_dq[511:0]','test_engine_debug_first[319:0]']
  first|=(1<<297)|(32<<291)
  values=[1,summary,errors,errors<<(9*32),first]
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.csv'
   with p.open('w') as f:
    w=csv.writer(f);w.writerow(names);w.writerow(['HEX']*len(names));w.writerow([f'{v:x}' for v in values])
   return decode(p)
 def test_pass(self):self.assertTrue(self.capture()['passed'])
 def test_dq9(self):
  r=self.capture(errors=1);self.assertEqual(r['first_error']['dq'],[9]);self.assertEqual(r['dense_errors'],1);self.assertEqual(r['sparse_errors'],0)
 def test_fatal(self):
  with self.assertRaises(ValueError):self.capture(fatal=2)
 def test_incomplete(self):
  with self.assertRaises(AssertionError):self.capture(reads=1048575)

if __name__=='__main__':unittest.main()
