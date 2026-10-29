from pathlib import Path
import re,json
p=Path('output_files/Minimig.sta.rpt')
values=[(k.strip(),float(v)) for k,v in re.findall(r'Worst-case ([A-Za-z ]+?) slack is\s+(-?\d+(?:\.\d+)?)',p.read_text(errors='replace'))]
required={'setup','hold','recovery','removal','minimum pulse width'}
if not required.issubset({k for k,v in values}):
    raise SystemExit('Timing report is incomplete; no RBF will be packaged.')
result={'report':str(p),'worst_slack_ns':dict(values),'accepted':all(v>=0 for k,v in values)}
Path('output_files/timing-acceptance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
if not result['accepted']: raise SystemExit('Timing failed; no RBF will be packaged.')
