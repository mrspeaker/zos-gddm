/* rexx */
/*
    GDDM wireframe animation

exec 'earlec.gddm(aniwire1)'
*/

obj_ps='earlec.gddm(objtorus)'
xr = 0.08 /* rotation speeds */
yr = 0.1
zr = 0.04
rotations = 6 /* number of times to spin before exit */
zoom = 17
zoom_depth = 5
SCREEN_WIDTH=100

/* ========== Let's go ============= */

call load_parse_obj

Address link    'GDDMREXX INIT'
Address gddm

'GSUWIN 0 .SCREEN_WIDTH 0 .SCREEN_WIDTH'
'GSLT 1'

/* run for X spins aroun Y axis */
do dt=0 to pi() * rotations by yr
  call transform
  call render
  'FSFRCE'
end dt
'ASREAD . . .'

Address link    'GDDMREXX TERM'
exit

/* =========== transform verts ============== */
transform:
  do i=1 to vertn
    /* rot z */
    v1=verts.i.1 * cos(zr) - verts.i.2 * sin(zr)
    v2=verts.i.2 * cos(zr) + verts.i.1 * sin(zr)
    verts.i.1=v1
    verts.i.2=v2

    /* rot y */
    v1=verts.i.1 * cos(yr) + verts.i.3 * sin(yr)
    v3=verts.i.3 * cos(yr) - verts.i.1 * sin(yr)
    verts.i.1=v1
    verts.i.3=v3

    /* rot x */
    v2=verts.i.2 * cos(xr) - verts.i.3 * sin(xr)
    v3=verts.i.3 * cos(xr) + verts.i.2 * sin(xr)
    verts.i.2=v2
    verts.i.3=v3

  end
return 0

/* ============== Render ================*/
render:
  'FSPCLR' /* clear whole screen */

  zoff=-zoom + sin(dt) * zoom_depth /* zoom camera */
  num_tris=0
  do i=1 to facen
    f1=(faces.i.1)+0 /* needed the +0 cast for some reason! */
    f2=(faces.i.2)+0 /* on of the axes wouldn't return */
    f3=(faces.i.3)+0 /* non-zeros without it. */

    vx=verts.f1.1
    vy=verts.f1.2
    vz=verts.f1.3
    zz=vz /* collect z values to take avg */
    x1=clip(vx/scalez(vz+zoff))
    y1=clip(vy/scalez(vz+zoff))

    vx=verts.f2.1
    vy=verts.f2.2
    vz=verts.f2.3
    zz=zz+vz
    x2=clip(vx/scalez(vz+zoff))
    y2=clip(vy/scalez(vz+zoff))

    vx=verts.f3.1
    vy=verts.f3.2
    vz=verts.f3.3
    zz=zz+vz
    x3=clip(vx/scalez(vz+zoff))
    y3=clip(vy/scalez(vz+zoff))

    z_depth=trunc(((1 - (vz/3)) + 1) / 2) /* avg z */
    /*'GSLT .z_depth'*/ /* line type based on depth */
    'GSCOL .z_depth' /* line color based on depth */
    'GSMOVE .x1 .y1'
    'GSPLNE 3 (.x2 .x3 .x1) (.y2 .y3 .y1)'

    /* checking if more frequnt draws help */
    /* not sure it does... */
    num_tris = num_tris + 1
    if num_tris > 50 then
    do
      'FSFRCE'
      num_tris = 0
    end
  end i
return 0

/* ============= Parse obj file =============== */
load_parse_obj:
  if sysdsn("'"obj_ps"'")/='OK' then
  do
    say 'could not load obj ps.'
    exit(0)
  end
  "alloc dd(inp1) da('"obj_ps"') shr reus"
  "execio * diskr inp1 (stem in1. finis"

  vertn=0
  facen=0
  verts.=0
  faces.=0

  do i=1 to in1.0
    ch=substr(in1.i,1,1)
    if ch=='f' then
    do
      facen=facen+1
      parse var in1.i 3 f1 f2 f3 f4
      faces.facen.1 = f1
      faces.facen.2 = f2
      faces.facen.3 = f3
    end
    if ch=='v' then
    do
      vertn=vertn+1
      parse var in1.i 3 v1 v2 v3
      verts.vertn.1 = v1
      verts.vertn.2 = v2
      verts.vertn.3 = v3
    end
  end
  say 'verts: ' vertn '. faces:' facen
return 0

/* ============= Helpers/maths ===============*/
clip:
parse arg v
return ((v + 1) / 2) * SCREEN_WIDTH

scalez:
parse arg z
return ((((1 - z) + 1) / 2) * 1) + 1

r2r:   return arg(1)       // (pi() *2) /*normalize radians  a unit circle*/

tan:   procedure; parse arg x;  _= cos(x); if _=0  then
call tanErr;  return sin(x) / _
tanErr:  call tellErr 'tan(' || x") causes division by zero, X=" || x

/**/
cos:  procedure; parse arg x; x= r2r(x);     if x=0   then return 1;  a= abs(x)
      numeric fuzz min(6, digits() - 3);   if a=pi  then return -1;pih= pi * .5
      if a=pih | a=pih*3  then return 0;  pit= pi/3;   if a=pit  then return .5
      if a=pit + pit      then return -.5;                return .sinCos(1, -1)
/**/
sin:  procedure; arg x;x=r2r(x);if x=0
      then return 0;numeric fuzz min(5,max(1,digits()-3))
      if x=pi*.5    then return 1;       if x==pi * 1.5  then return -1
      if abs(x)=pi  then return 0;                        return .sinCos(x,1)
/**/
.sinCos: parse arg z 1 _,i;        q= x*x
         do k=2  by 2 until p=z;
         p= z;     _= - _ * q / (k * (k+i) );   z= z + _;
         end
         return z
/**/
 pi:  pi= 3.1415926535897
      return pi
