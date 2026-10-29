"""Gera os efeitos sonoros sintetizados do Find Her como WAV.
Uso: python3 tools/make_audio.py   (requer numpy)
Os sons imitam o sintetizador da versão HTML; troque por áudio profissional quando tiver."""
import numpy as np, wave, os
SR=22050
OUT=os.path.join(os.path.dirname(__file__),'..','assets','audio')
def osc(kind,f,n):
    t=np.arange(n)/SR
    if np.ndim(f)==0: ph=2*np.pi*f*t
    else: ph=2*np.pi*np.cumsum(f)/SR
    if kind=='sine':return np.sin(ph)
    if kind=='square':return np.sign(np.sin(ph))*.8
    if kind=='triangle':return 2/np.pi*np.arcsin(np.sin(ph))
    if kind=='sawtooth':return 2*((ph/(2*np.pi))%1)-1
def env(n,vol,att=.01):
    a=max(1,int(att*SR));e=np.ones(n)*vol;e[:a]=np.linspace(0,vol,a)
    e[a:]=vol*np.exp(np.linspace(0,np.log(.001/max(vol,1e-4)),n-a)) if n>a else e[a:];return e
def tone(buf,f,t0,dur,kind='square',vol=.15,f2=None):
    n=int(dur*SR);i=int(t0*SR)
    fr=f if f2 is None else f*np.exp(np.linspace(0,np.log(f2/f),n))
    s=osc(kind,fr,n)*env(n,vol)
    end=min(len(buf),i+n);buf[i:end]+=s[:end-i]
def lowpass(x,fc):
    a=np.exp(-2*np.pi*fc/SR);y=np.zeros_like(x);p=0.
    for k in range(len(x)):p=(1-a)*x[k]+a*p;y[k]=p
    return y
def noise(buf,t0,dur,vol=.3,fc=1200):
    n=int(dur*SR);i=int(t0*SR);x=(np.random.rand(n)*2-1)*(1-np.arange(n)/n);x=lowpass(x,fc)*vol*2.2
    end=min(len(buf),i+n);buf[i:end]+=x[:end-i]
def save(name,buf,gain=1.0):
    b=np.clip(buf*gain,-1,1);d=(b*32000).astype(np.int16)
    with wave.open(os.path.join(OUT,name+'.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(d.tobytes())
def sfx(name,dur,fn):
    b=np.zeros(int(dur*SR));fn(b);save(name,b,1.6)
np.random.seed(7)
sfx('jump',.2,lambda b:tone(b,320,0,.12,'square',.08,620))
sfx('dj',.2,lambda b:tone(b,480,0,.12,'square',.08,900))
sfx('pen',.22,lambda b:(tone(b,1320,0,.07,'triangle',.12),tone(b,1760,.06,.1,'triangle',.1)))
sfx('stomp',.2,lambda b:(tone(b,220,0,.12,'square',.14,80),noise(b,0,.08,.2,800)))
sfx('hurt',.3,lambda b:tone(b,400,0,.25,'sawtooth',.12,120))
sfx('item',.5,lambda b:[tone(b,f,i*.07,.14,'triangle',.12) for i,f in enumerate([523,659,784,1046])])
sfx('clue',.75,lambda b:[tone(b,f,i*.11,.3,'sine',.14) for i,f in enumerate([392,523,659,784])])
sfx('combine',.6,lambda b:[tone(b,f,i*.08,.2,'square',.07) for i,f in enumerate([523,659,784,1046,1318])])
sfx('unlock',.6,lambda b:(noise(b,0,.15,.3,600),tone(b,150,0,.3,'square',.1,90),tone(b,660,.25,.3,'triangle',.12)))
sfx('splash',.3,lambda b:noise(b,0,.25,.35,1800))
sfx('slide',.22,lambda b:noise(b,0,.18,.15,2500))
sfx('fire',.45,lambda b:(noise(b,0,.4,.25,900),tone(b,200,0,.3,'triangle',.06,400)))
sfx('thunder',1.7,lambda b:noise(b,0,1.6,.5,220))
sfx('door',.9,lambda b:[tone(b,f,i*.12,.5,'triangle',.12) for i,f in enumerate([262,330,392,523])])
sfx('spring',.25,lambda b:tone(b,200,0,.2,'sine',.15,800))
sfx('climb',.05,lambda b:tone(b,900,0,.03,'triangle',.03))
sfx('die',.8,lambda b:[tone(b,f,i*.12,.18,'square',.08) for i,f in enumerate([523,392,330,262,196])])
sfx('special',.5,lambda b:[tone(b,f,i*.06,.25,'triangle',.12) for i,f in enumerate([784,988,1175,1568])])
# chuva (loop de 4 s com emenda suave)
n=SR*4;x=lowpass(np.random.rand(n+SR)*2-1,1600);a=x[:n].copy();f=SR;w=np.linspace(0,1,f);a[:f]=a[:f]*w+x[n:n+f]*(1-w);save('rain',a*.9)
# As músicas, os ambientes e os efeitos 'clue item pen special door combine die fire' são gravados com
# instrumentos reais por tools/make_music.py (rode-o depois deste script).

# rugido do Javali-Rei e latido do Pipoca
from scipy.signal import lfilter, butter
rg=np.random.default_rng(3)
n=int(1.6*SR);t=np.arange(n)/SR
f=95+25*np.sin(2*np.pi*6*t)+np.interp(t,[0,.3,1.6],[60,0,-30]);ph=2*np.pi*np.cumsum(f)/SR
saw=sum(np.sin(k*ph)/k for k in range(1,14))
nz=lfilter(*butter(2,[300/(SR/2),1800/(SR/2)],'band'),rg.standard_normal(n))
r=(saw*.6+nz*2.2)*np.interp(t,[0,.12,1.1,1.6],[0,1,.8,0])*(1+.35*np.sin(2*np.pi*23*t))
r=lfilter(*butter(2,2400/(SR/2)),r);save('roar',r/np.max(np.abs(r))*.9)
def au(d=.16,f0=520):
    n=int(d*SR);t=np.arange(n)/SR;ph=2*np.pi*np.cumsum(f0*np.exp(-t*4)+180)/SR
    x=sum(np.sin(k*ph)*(.8**k) for k in range(1,10))+lfilter(*butter(2,[800/(SR/2),3000/(SR/2)],'band'),rg.standard_normal(n))*1.5
    return x*np.interp(t,[0,.01,d*.4,d],[0,1,.6,0])
b=np.concatenate([au(),np.zeros(int(.07*SR)),au(.14,600)]);save('bark',b/np.max(np.abs(b))*.9)
