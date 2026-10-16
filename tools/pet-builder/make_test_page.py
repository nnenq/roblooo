import json,sys
spec=open(sys.argv[1]).read(); core=open(sys.argv[2]).read()
html='''<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;background:#fff}canvas{width:%dpx;height:%dpx;display:block}</style></head>
<body><canvas id="c"></canvas><script type="module">
import * as THREE from "/three.module.js";
const SPEC = %s;
%s
window.v = mountKrotik(document.getElementById("c"), {capture:true, still:true, yaw:-0.5});
window.ready = true;
</script></body></html>''' % (int(sys.argv[3]), int(sys.argv[3]), spec, core)
open(sys.argv[4] if len(sys.argv) > 4 else 'test/index.html','w').write(html)
