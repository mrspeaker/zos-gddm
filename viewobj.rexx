/* rexx */
/*
    GDDM obj file wireframe viewer

    Due to bad parsing code (TODO: fix it!), faces need to be
    ONLY 3 values: eg
      f 1 2 3
      f 1/1/1 2/1/1 3/2/2

exec 'earlec.gddm(viewobj)'
*/
obj_ps='earlec.gddm(objhead)'
SCREEN_WIDTH=100

fill=0

call pi
/* rotation (radians) */
xr = 0
yr = 0 /*-pi()/8 */
zr = 0
/* camera zoom */
zoom = 0

/* Not correct! Just a "fudge factor" at the moment */
angle_of_view = 70
fov = tan(angle_of_view * 0.5 * pi() / 180)

/* ============ Let's go =============== */
Signal on Error                        /* Set up error handling     */
Signal on Syntax                       /*                           */
Signal on Halt                         /*                           */

/* Load the obj file into `verts` and `faces` */
call load_parse_obj

Address link    'GDDMREXX INIT'
Address gddm

'GSUWIN 0 .SCREEN_WIDTH 0 .SCREEN_WIDTH'
'GSENAB 1 1 1'   /* enable PF keys */

frame = 0
do forever
  call transform
  call render
  'FSFRCE'
  yr = 0

  fudge = sin(frame/3)
   /*'GSREAD 1 . .'
   'GSQCHO .pfkey'*/
  "ASREAD .attype .atval ." /* read pf keys */
  if attype == 1 then
  do
    if atval == 3 then signal endit
    if atval == 4 then zoom = zoom + 1
    if atval == 5 then zoom = zoom - 1
    if atval == 6 then yr = -pi/8
    if atval == 7 then yr = pi/8
    if atval == 8 then
    do
      if fill == 0 then fill = 1
      else fill = 0
    end
  end
end

/* ============ And we're done ===============*/
Error:
Syntax:
    Say 'Exec ended abnormally. Return code' rc 'from line' sigl'.'
    Say  sourceline(sigl)
Halt:
Endit:
Address link    'GDDMREXX TERM'
exit

/* ========================================= */
/* =                ROUTINES               = */
/* ========================================= */

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
  'FSPCLR'
  'GSCOL -2'
  'GSCHAR 0 0 28 "PF3 Exit |"'
  'GSCHAR 7 0 28 "PF4 Zoom out |"'
  'GSCHAR 16 0 28 "PF5 Zoom in |"'
  'GSCHAR 24.5 0 28 "PF6 Rot Y CW |"'
  'GSCHAR 34 0 28 "PF7 Rot Y CCW"'

  num_tris=0
  zoff=-zoom
  do i=1 to facen
    f1=(faces.i.1)+0 /* Needed the +0 cast for some reason! */
    f2=(faces.i.2)+0 /* One of the axes wouldn't return */
    f3=(faces.i.3)+0 /* non-zeros without it. */

    fn1=(facenorms.i.1)+0
    fn2=(facenorms.i.2)+0
    fn3=(facenorms.i.3)+0
    /** Lol, just using first vertex normal. TODO: um, use all three? */
    vnx=norms.fn1.1
    vny=norms.fn1.2
    vnz=norms.fn1.3
       /* pick pattern*/
    dp=8-trunc(((vnx*0)+(vny*0)+(vnz*1)) * 8)

    /* Convert to clip coords */
    vx1=verts.f1.1
    vy1=verts.f1.2
    vz1=verts.f1.3
    zz=vz1 /* collect z values to take avg */
    x1=clip(vx1 / scalez(vz1 + zoff))
    y1=clip(vy1  /scalez(vz1 + zoff))

    vx2=verts.f2.1
    vy2=verts.f2.2
    vz2=verts.f2.3
    zz=zz+vz2
    x2=clip(vx2 / scalez(vz2  +zoff))
    y2=clip(vy2  /scalez(vz2 + zoff))

    vx3=verts.f3.1
    vy3=verts.f3.2
    vz3=verts.f3.3
    zz=zz + vz3
    x3=clip(vx3 / scalez(vz3 + zoff))
    y3=clip(vy3 / scalez(vz3 + zoff))

    /* shoelace for backface culling */
    area=(vx1*vy2-vx2*vy1) + (vx2*vy3-vx3*vy2) + (vx3*vy1-vx1*vy3)
    if area < 0 then
      iterate

    /* Center and calc normal line */
    cx=(vx1 + vx2 + vx3) / 3
    cy=(vy1 + vy2 + vy3) / 3
    cz=(vz1 + vz2 + vz3) / 3
    xc=clip(cx / scalez(cz + zoff))
    yc=clip(cy / scalez(cz + zoff))

    nx=cx + vnx
    ny=cy + vny
    nz=cz + vnz
    xn=clip(nx / scalez(nz + zoff))
    yn=clip(ny / scalez(nz + zoff))

    z_depth=trunc(((1 - (vz3 / 3)) + 1) / 2) /* avg z */
    'GSLT .z_depth' /* line type based on depth */
    'GSCOL .z_depth' /* line color based on depth */
    if fill then 'GSPAT .dp'
    if fill then 'GSAREA 1'
    'GSMOVE .x1 .y1'
    'GSPLNE 3 (.x2 .x3 .x1) (.y2 .y3 .y1)'
    if fill then 'GSENDA'
    /*'GSCOL -2'
    'GSMOVE .xc .yc'
    'GSLINE .xc .yC'*/

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
  verts.=0
  normn=0
  norms.=0
  facen=0
  faces.=0
  facenorms.=0

  do i=1 to in1.0
    ch=substr(in1.i,1,2)
    /* Faces */
    if ch=='f ' then
    do
      facen=facen+1
      parse var in1.i 3 f1 f2 f3
      parse var f1 f1 '/' f1n '/' f1u
      parse var f2 f2 '/' f2n '/' f2u
      parse var f3 f3 '/' f3n '/' f3u

      faces.facen.1 = f1
      faces.facen.2 = f2
      faces.facen.3 = f3
      if f1n > 0 then
      do
        facenorms.facen.1 = f1n
        facenorms.facen.2 = f2n
        facenorms.facen.3 = f3n
      end
    end
    /* Verts */
    if ch=='v ' then
    do
      vertn=vertn+1
      parse var in1.i 3 v1 v2 v3
      verts.vertn.1 = v1
      verts.vertn.2 = v2
      verts.vertn.3 = v3
    end
    /* Normals */
    if ch=='vn' then
    do
      normn=normn+1
      parse var in1.i 3 n1 n2 n3
      norms.normn.1 = n1
      norms.normn.2 = n2
      norms.normn.3 = n3
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
return ((((1 - z) + 1) / 2) + 1) * fov

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
 pi:  pi= 3.141592653589
      return pi /*Note:  the actual PI subroutine returns PI's accuracy that */
