"""Validate planning data and run a deliberately simplified tower-only model.

Not game runtime code. Uses Python standard library only.
"""
from pathlib import Path
import json, math, random, statistics, hashlib

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'game/data'
def read(p):return json.loads((DATA/p).read_text(encoding='utf-8'))
MAP=read('maps/confluence_courtyard.json')
TD=read('towers.json');ED=read('enemies.json');WD=read('waves/courtyard_normal.json');RULE=read('rules.json')
TOWERS={x['id']:x for x in TD['towers']};ENEMIES={x['id']:x for x in ED['enemies']}
NODES={x['id']:x for x in MAP['nodes']}
def length(route):return sum(math.dist(a,b) for a,b in zip(route,route[1:]))
def point(route,s):
 for a,b in zip(route,route[1:]):
  d=math.dist(a,b)
  if s<=d:
   return [a[0]+(b[0]-a[0])*s/d,a[1]+(b[1]-a[1])*s/d]
  s-=d
 return route[-1]
def near_segment(p,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1]
 t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
 return math.dist(p,(a[0]+dx*t,a[1]+dy*t))

def validate():
 checks=[]
 def ck(name,ok):
  checks.append((name,bool(ok)))
  if not ok:raise AssertionError(name)
 for f in DATA.rglob('*.json'):ck(f'{f.relative_to(DATA)} schema_version',json.loads(f.read_text(encoding='utf-8'))['schema_version']==1)
 ck('16 unique tower nodes',len(MAP['nodes'])==len(NODES)==16)
 for n in MAP['nodes']:
  x,y=n['position'];ck(n['id']+' coordinate',0<=x<32 and 0<=y<24)
  ck(n['id']+' ownership',n['owner'] in ['p1','p2','shared'])
  nearest=min(near_segment(n['position'],a,b) for key in ['a_default','b_default'] for a,b in zip(MAP['routes'][key],MAP['routes'][key][1:]))
  ck(n['id']+' outside road',nearest>=.75)
 for key,r in MAP['routes'].items():
  ck(key+' no duplicate or backward waypoints',len({tuple(p) for p in r})==len(r) and all(a[0]<b[0] for a,b in zip(r,r[1:])))
  ck(key+' within map',all(0<=x<32 and 0<=y<24 for x,y in r))
 for g in MAP['gates']:
  before=MAP['routes'][g['from_route']];after=MAP['routes'][g['to_route']]
  ck(g['id']+' shared prefix',before[:4]==after[:4] and before[-1]!=after[-1])
 ck('unique tower IDs',len(TOWERS)==len(TD['towers'])==5)
 ck('unique enemy IDs',len(ENEMIES)==len(ED['enemies'])==6)
 for t in TD['towers']:
  ck(t['id']+' positive cost',t['cost']>0)
  if 'interval' in t:ck(t['id']+' interval',t['interval']>0 and t['range']>0)
  ck(t['id']+' targets',set(t['targets'])<= {'ground','air'} and bool(t['targets']))
 for e in ED['enemies']:
  ck(e['id']+' numeric bounds',e['base_hp']>0 and e['speed']>0 and 0<=e['physical_resistance']<=.8 and 0<=e['magic_resistance']<=.8)
 ck('20 Hz and 10 Hz divisible',RULE['simulation_hz']%RULE['snapshot_hz']==0)
 ck('different valid ports',0<RULE['network_port']<65536 and 0<RULE['discovery_port']<65536 and RULE['network_port']!=RULE['discovery_port'])
 ck('ten contiguous waves',[w['wave'] for w in WD['waves']]==list(range(1,11)))
 for w in WD['waves']:
  ck(f'wave {w["wave"]} known IDs and entries',all(ev['enemy_id'] in ENEMIES and ev['entry'] in ['a','b'] for ev in w['events']))
  ck(f'wave {w["wave"]} sorted positive time',all(e['time']>=0 for e in w['events']) and w['events']==sorted(w['events'],key=lambda e:(e['time'],e['entry'])))
 count=sum(len(w['events']) for w in WD['waves'])
 bounty=sum(ENEMIES[e['enemy_id']]['bounty'] for w in WD['waves'] for e in w['events'])
 ck('expected total enemies',count==206);ck('expected bounty',bounty==1513)
 heroes=read('heroes.json')['heroes']
 ck('hero IDs',len({x['id'] for x in heroes})==len(heroes)==6)
 ck('normal and diverted route lengths match',abs(length(MAP['routes']['a_default'])-length(MAP['routes']['a_diverted']))<1e-9)
 cfg_hash=hashlib.sha256()
 for f in sorted(DATA.rglob('*.json')):
  cfg_hash.update(f.relative_to(DATA).as_posix().encode());cfg_hash.update(f.read_bytes())
 text=['# 配置与几何检查报告','',f'全部 {len(checks)} 项检查通过。设计校验不等于引擎导入或游戏运行验收。','',f'- 敌人总数：{count}',f'- 基础总赏金：{bounty}g',f'- 波次奖励每人：{sum(w["reward_per_player"] for w in WD["waves"])}g',f'- 地面路线长度：{length(MAP["routes"]["a_default"]):.4f} 格',f'- 空中路线长度：{length(MAP["routes"]["air_a"]):.4f} 格',f'- 配置内容 SHA256：`{cfg_hash.hexdigest()}`','', '|检查|结果|','|---|---|']+[f'|{name}|通过|' for name,_ in checks]
 (ROOT/'docs/validation/config-report.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
 return len(checks)

BASE=[('p1','p1_01','archer'),('p2','p2_01','archer'),('p1','shared_01','frost'),('p2','shared_02','cannon')]
def run(seed,combo_enabled=True,placements=BASE,upgrade_before_wave3=False):
 rng=random.Random(seed);gold={'p1':300*4,'p2':300*4}
 for owner,node,tid in placements:
  assert NODES[node]['owner'] in ['shared',owner]
  gold[owner]-=TOWERS[tid]['cost']*4
 assert all(v>=0 for v in gold.values())
 result=[];dt=1/RULE['simulation_hz'];crystal=20
 for wave in WD['waves'][:3]:
  if crystal<=0:break
  upgrade=upgrade_before_wave3 and wave['wave']==3
  if upgrade:
   for owner,node,tid in placements:
    if tid in ['frost','cannon']:
     gold[owner]-=math.ceil(TOWERS[tid]['cost']*.8)*4
   assert all(v>=0 for v in gold.values()),'upgrade plan exceeds budget'
  active=[];spawn=0;time=0;kill=0;leak=0;combos=0;synergies=0;leak_hp=0
  towers=[{'owner':o,'pos':NODES[n]['position'],'spec':TOWERS[t],'next':0} for o,n,t in placements]
  if upgrade:
   for tower in towers:
    if tower['spec']['id'] in ['frost','cannon']:
     tower['spec']=dict(tower['spec']);tower['spec']['damage']*=1.5
  def hit(e,amount,typ,owner):
   resist=e['spec'].get(typ+'_resistance',0) if typ!='true' else 0
   e['hp']-=amount*(1-resist)
   if amount>0:e['contrib'][owner]=time
  while time<300:
   while spawn<len(wave['events']) and wave['events'][spawn]['time']<=time+1e-8:
    event=wave['events'][spawn];spec=ENEMIES[event['enemy_id']]
    route=MAP['routes'][event['entry']+'_default']
    active.append({'id':spawn,'spec':spec,'route':route,'length':length(route),'s':0,'hp':math.floor(spec['base_hp']*(1+.08*(wave['wave']-1))+.5),'frost_end':-1,'frost_owner':None,'mark_end':-1,'mark_owner':None,'shatter_end':-1,'contrib':{}})
    spawn+=1
   for e in active:
    slow=.4 if e['frost_end']>time else 0
    e['s']+=e['spec']['speed']*(1-slow)*dt;e['pos']=point(e['route'],e['s'])
   for tower in towers:
    if tower['next']>time+1e-8:continue
    spec=tower['spec'];owner=tower['owner']
    targets=[e for e in active if e['hp']>0 and math.dist(tower['pos'],e['pos'])<=spec['range']]
    if not targets:continue
    e=min(targets,key=lambda e:(e['length']-e['s'],e['id']));tower['next']=time+spec['interval']
    crit=combo_enabled and e['mark_end']>time and e['mark_owner']!=owner and rng.random()<.5
    if spec['id']=='cannon':
     shatter=combo_enabled and e['frost_end']>time and e['frost_owner']!=owner and e['shatter_end']<=time
     near=[other for other in active if other is not e and other['hp']>0]
     if shatter:
      hit(e,spec['damage']*3,'true',owner);e['contrib'][e['frost_owner']]=time;e['frost_end']=-1;e['shatter_end']=time+2;combos+=1
     else:hit(e,spec['damage']*(2 if crit else 1),'physical',owner)
     for other in near:
      d=math.dist(e['pos'],other['pos'])
      if d<=1.2:hit(other,spec['damage'],'physical',owner)
      if shatter and d<=2:
       hit(other,spec['damage']*3*.5,'true',owner);other['contrib'][e['frost_owner']]=time
    else:
     hit(e,spec['damage']*(2 if crit else 1),spec['damage_type'],owner)
     if spec['id']=='frost' and e['hp']>0:e['frost_end']=time+3;e['frost_owner']=owner
     if spec['id']=='archer' and rng.random()<.15 and e['hp']>0:e['mark_end']=time+5;e['mark_owner']=owner
   alive=[]
   for e in active:
    if e['hp']<=0:
     kill+=1
     contrib={k for k,v in e['contrib'].items() if time-v<=3}
     if e['frost_end']>time:contrib.add(e['frost_owner'])
     if e['mark_end']>time:contrib.add(e['mark_owner'])
     both={'p1','p2'}<=contrib;synergies+=int(both)
     for owner in gold:gold[owner]+=e['spec']['bounty']*(3 if both else 2)
    elif e['s']>=e['length']:
     leak+=1;leak_hp+=e['spec']['leak_damage'];crystal=max(0,crystal-e['spec']['leak_damage'])
    else:alive.append(e)
   active=alive
   if crystal==0:break
   if spawn==len(wave['events']) and not active:break
   time+=dt
  assert time<300,'simulation did not clear'
  if crystal>0:
   for owner in gold:gold[owner]+=wave['reward_per_player']*4
  result.append({'wave':wave['wave'],'kills':kill,'leaks':leak,'leak_hp':leak_hp,'shatters':combos,'synergies':synergies,'clear_seconds':round(time,2),'crystal_hp':crystal,'gold_p1':gold['p1']/4,'gold_p2':gold['p2']/4})
 return result

def simulation():
 rows=[]
 cases=[('中央协作',True,BASE,False),('中央协作＋升级',True,BASE,True),('连锁关闭对照',False,BASE,False),('分散防线',True,[('p1','p1_01','archer'),('p2','p2_01','archer'),('p1','p1_05','frost'),('p2','p2_05','cannon')],False)]
 all_results={}
 for name,combo,placement,upgrade in cases:
  runs=[run(seed,combo,placement,upgrade) for seed in range(20)]
  all_results[name]={'placement':placement,'upgrade_before_wave3':upgrade,'runs':runs}
  for wi in range(3):
   rr=[r[wi] for r in runs]
   rows.append([name,str(wi+1),f'{min(x["leaks"] for x in rr)}–{max(x["leaks"] for x in rr)}',f'{statistics.mean(x["clear_seconds"] for x in rr):.1f}',f'{statistics.mean(x["shatters"] for x in rr):.1f}',f'{statistics.mean(x["synergies"] for x in rr):.1f}',f'{min(x["crystal_hp"] for x in rr)}–{max(x["crystal_hp"] for x in rr)}'])
 (ROOT/'docs/validation/simulation-results.json').write_text(json.dumps(all_results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 text=['# 前三波简化推演','', '模型读取当前 JSON，按 20 Hz、真实折线路程和欧氏射程计算。种子 0 至 19 各运行一次，共 80 组、240 个波次。所有布局开局造价均为 P1 220g、P2 225g；不卖塔、不用英雄或机关。仅升级场景在第 3 波前分别花费 96g／100g 将中央冰霜与火炮升到二级；其余场景不升级。','', '|场景|波|漏怪范围|平均清场秒|平均冰碎|平均协同击杀|波后水晶 HP|','|---|---|---|---|---|---|---|']+['|'+'|'.join(r)+'|' for r in rows]
 text+=['','## 模型假设与边界','','- 地面怪按原始队列生成，移动后索敌，最接近出口优先。','- 塔使用即时命中，未模拟炮弹飞行或躲避；实际炮弹射程与落点可能降低效果。','- 保留抗性、冰霜、标记、随机暴击、炮击溅射和冰碎；连锁关闭对照仅关闭冰碎与跨玩家标记暴击，仍保留控制和协同赏金。','- 没有士兵、英雄、油污、机关、断线与操作延迟。模拟采用固定席位和固定四塔，不等同于玩家行为。','- 时长列为清场或失败结束时间；HP 归零立即结束，不发波次奖励。不含首轮 60 秒准备、两次 25 秒准备和教学。','- 波内记录金币仅供预算参考，只有升级场景消费后续余额。','- 该工具不用于替代游戏逻辑实现，也没有证明十波平衡、20 至 25 分钟局长或实机性能。','','## 开工时的核对','','先在引擎复现中央协作与升级布局前 3 波，比较漏怪、冰碎和清场时间。若结果偏离，优先检查炮弹落点、状态有效期、索敌与射程，而非立即提高塔伤害。实际真人试玩前不称该关卡已经平衡。']
 (ROOT/'docs/validation/first-three-waves.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
 return rows

if __name__=='__main__':
 print('checks passed:',validate())
 for row in simulation():print(' | '.join(row))
