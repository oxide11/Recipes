"""Assemble index.html from src/. Run: python3 build.py"""
r=lambda p:open('src/'+p).read()
boot="speedSeg();recipeSeg();devSeg();fit();render(true);"
app=r('app.js').replace(boot,"")
js="\n".join([r('data_base.js'),r('recipes.js'),app,r('pad.js'),boot])
open('index.html','w').write(r('shell.html').replace('/*CSS*/',r('base.css')+r('pad.css')).replace('/*JS*/',js))
