/* rexx */
/*
  GDDM obj file wireframe viewer

  Faces must be triangles (ONLY 3 values). eg:
    f 1 2 3
    f 1/1/1 2/1/1 3/2/2

exec 'earlec.gddm(viewobj)'
*/
obj_ps = 'earlec.gddm(objhead)'
SCREEN_WIDTH = 100

xcam = 0; ycam = 0; zcam = 0 /* camera pos */
xpos = 0; ypos = 0; zpos = 0 /* model pos */
xrot = 0; yrot = 0; zrot = 0 /* model rotation (radians) */

/* Not correct! Just a "fudge factor" at the moment */
angle_of_view = 70
fov = tan(angle_of_view * 0.5 * pi() / 180)
fill = 0 /* Fill triangles == 1 */

/* ============ Let's go =============== */
Signal on Error                        /* Set up error handling     */
Signal on Syntax                       /*                           */
Signal on Halt                         /*                           */

/* consts: Indices to vectors and lengths */
num = 0 /* length of stem */
x = 1; y = 2; z = 3 /* vector idx */

overts. = 0 /* current object to draw (copies and transforms from `verts`) */

/* Load the obj file into `verts` and `faces` */
call load_parse_obj

/* init gddm */
Address link    'GDDMREXX INIT'
Address gddm
'GSUWIN 0 .SCREEN_WIDTH 0 .SCREEN_WIDTH'
'GSENAB 1 1 1'   /* enable PF keys */

/* main loop */
do forever
  'FSPCLR'
  call render_instructions

  xpos = xcam + 0; ypos = ycam + 0; zpos = zcam + 0
  call drawobj

  xpos = xcam -1; ypos = ycam + 0; zpos = zcam + 2
  call drawobj

  xpos = xcam + 1; ypos = ycam + 0; zpos = zcam + 4
  call drawobj

  'FSFRCE'
  call input
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

drawobj:
  /* Like a gl "draw call": transform verts and render them */
  call transform
  call render
  return 0

/* =========== handle PF keys ============== */
input:
  'ASREAD .attype .atval .' /* read pf keys */
  if attype == 1 then
  do
    if atval == 3 then signal endit
    if atval == 4 then zcam = zcam + 1
    if atval == 5 then zcam = zcam - 1
    if atval == 6 then yrot = yrot - pi/8
    if atval == 7 then yrot = yrot + pi/8
    if atval == 8 then
    do
      if fill == 0 then fill = 1
      else fill = 0
    end
  end
return

/* =========== transform verts ============== */
transform:
  overts. = verts. /* copy `verts` to `overts` and transform */
  do i = 1 to verts.num
    overts.i. = verts.i.
    /* rot z */
    overts.i.x = verts.i.x * cos(zrot) - verts.i.y * sin(zrot)
    overts.i.y = verts.i.y * cos(zrot) + verts.i.x * sin(zrot)
    overts.i.z = verts.i.z

    /* rot y */
    overts.i.x = overts.i.x * cos(yrot) + overts.i.z * sin(yrot)
    overts.i.z = overts.i.z * cos(yrot) - overts.i.x * sin(yrot)

    /* rot x */
    overts.i.y = overts.i.y * cos(xrot) - overts.i.z * sin(xrot)
    overts.i.z = overts.i.z * cos(xrot) + overts.i.y * sin(xrot)

    overts.i.x = overts.i.x - xpos
    overts.i.y = overts.i.y - ypos
    overts.i.z = overts.i.z - zpos
  end
return 0

/* ============== Render current model ================*/
render:
  do i=1 to faces.num
    f1 = (faces.i.1)+0 /* Needed the +0 cast for some reason! */
    f2 = (faces.i.2)+0 /* One of the axes wouldn't return */
    f3 = (faces.i.3)+0 /* non-zeros without it. */

    fn1 = (facenorms.i.1)+0
    fn2 = (facenorms.i.2)+0
    fn3 = (facenorms.i.3)+0
    /** Just using first vertex normal. TODO: um, use all three */
    vnx = norms.fn1.x; vny = norms.fn1.y; vnz = norms.fn1.z

    /* pick pattern*/
    dp = 8 - trunc(((vnx*0)+(vny*0)+(vnz*1)) * 8)

    /* Convert to clip coords */
    vx1 = overts.f1.x
    vy1 = overts.f1.y
    vz1 = overts.f1.z
    zz = vz1 /* collect z values to take avg */
    x1 = clip(vx1 / scalez(vz1))
    y1 = clip(vy1  /scalez(vz1))

    vx2 = overts.f2.x
    vy2 = overts.f2.y
    vz2 = overts.f2.z
    zz = zz + vz2
    x2 = clip(vx2 / scalez(vz2))
    y2 = clip(vy2  /scalez(vz2))

    vx3 = overts.f3.x
    vy3 = overts.f3.y
    vz3 = overts.f3.z
    zz = zz + vz3
    x3 = clip(vx3 / scalez(vz3))
    y3 = clip(vy3 / scalez(vz3))

    /* shoelace for backface culling */
    area = (vx1*vy2-vx2*vy1) + (vx2*vy3-vx3*vy2) + (vx3*vy1-vx1*vy3)
    if area < 0 then
      iterate

    /* Center and calc normal line */
    cx = (vx1 + vx2 + vx3) / 3
    cy = (vy1 + vy2 + vy3) / 3
    cz = (vz1 + vz2 + vz3) / 3
    xc = clip(cx / scalez(cz))
    yc = clip(cy / scalez(cz))

    nx = cx + vnx; ny = cy + vny; nz = cz + vnz
    xn = clip(nx / scalez(nz))
    yn = clip(ny / scalez(nz))

    z_depth = trunc(zcam + (((1 - (vz3 / 3)) + 1) / 2)) /* avg z */
    if (z_depth < 0) then z_depth = 0
    'GSLT .z_depth'  /* line type based on depth */
    'GSCOL .z_depth' /* line color based on depth */
    if fill then 'GSPAT .dp'
    if fill then 'GSAREA 1'
    'GSMOVE .x1 .y1'
    'GSPLNE 3 (.x2 .x3 .x1) (.y2 .y3 .y1)'
    if fill then 'GSENDA'
    /*if fill == 0 then 'GSMARK .xc .yc'*/
  end i
  'fsfrce'
return 0


/* ============= UI instructions =============== */
render_instructions:
  'GSCOL -2'
  'GSCHAR 0 0 28 "PF3 Exit |"'
  'GSCHAR 7 0 28 "PF4 Cam out |"'
  'GSCHAR 16 0 28 "PF5 Cam in |"'
  'GSCHAR 24.5 0 28 "PF6 Rot Y CW |"'
  'GSCHAR 34 0 28 "PF7 Rot Y CCW |"'
  'GSCHAR 44 0 28 "PF8 Fill on/off"'

  vtext = "verts:" verts.num
  'GSCHAR 92 98 28 .vtext'
  ftext = "faces:" faces.num
  'GSCHAR 92 96.5 28 .ftext'
return 0

/* ============= Parse obj file =============== */
load_parse_obj:
  if sysdsn("'"obj_ps"'") /= 'OK' then
  do
    say 'could not load obj ps.'
    exit(0)
  end
  "alloc dd(inp1) da('"obj_ps"') shr reus"
  "execio * diskr inp1 (stem in1. finis"

  idx = 0
  verts. = 0
  norms. = 0
  faces. = 0
  facenorms. = 0

  do i = 1 to in1.num
    ch = substr(in1.i, 1, 2)
    /* Faces */
    if ch=='f ' then
    do
      parse var in1.i 3 f1 f2 f3
      parse var f1 f1 '/' f1n '/' f1u
      parse var f2 f2 '/' f2n '/' f2u
      parse var f3 f3 '/' f3n '/' f3u

      faces.num = faces.num + 1; idx = faces.num
      faces.idx.1 = f1
      faces.idx.2 = f2
      faces.idx.3 = f3
      if f1n > 0 then
      do
        facenorms.idx.1 = f1n
        facenorms.idx.2 = f2n
        facenorms.idx.3 = f3n
      end
    end
    /* Verts */
    if ch == 'v ' then
    do
      parse var in1.i 3 v1 v2 v3
      verts.num = verts.num + 1; idx = verts.num
      verts.idx.x = v1
      verts.idx.y = v2
      verts.idx.z = v3
    end
    /* Normals */
    if ch=='vn' then
    do
      parse var in1.i 3 n1 n2 n3
      norms.num = norms.num + 1; idx = norms.num
      norms.idx.x = n1
      norms.idx.y = n2
      norms.idx.z = n3
    end
  end
return 0

/* ============= Helpers/maths ===============*/
clip:
  parse arg vvvv
  return ((vvvv + 1) / 2) * SCREEN_WIDTH

scalez:
  parse arg zzzz
  return ((((1 - zzzz) + 1) / 2) + 1) * fov

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
 pi:  pi = 3.141592653589
      return pi

