import sys, json
sys.path.insert(0,'/home/inaba/kxr_cube_solver/scripts')
import cv2, numpy as np
import vision, config
from helpers import bgr2lab, ciede2000
img=cv2.imread('/home/inaba/kxr_cube_solver/images/gui.png')
det=vision.cubeDetector()
out=[]
for k,roi in enumerate(det.rois):
    patch=vision.getROI(img,roi,det.roi_size)
    dom=vision.get_dominant_color(patch)
    lab=bgr2lab(dom)
    ds=[(n, ciede2000(lab,bgr2lab(c))) for n,c in config.colors]
    ds.sort(key=lambda x:x[1])
    cv2.imwrite('roi_%d.png'%k, patch)
    out.append({"roi":roi,"bgr":[float(x) for x in dom],"lab":lab,"best":ds[0],"second":ds[1]})
    print(k, roi, [round(float(x)) for x in dom], [round(v,1) for v in lab], ds[0][0], round(ds[0][1],1), ds[1][0], round(ds[1][1],1))
json.dump(out,open('vision_result.json','w'),indent=1)
# overlay ROI boxes on a clean copy for a figure
vis=img.copy()
for roi in det.rois:
    cv2.rectangle(vis,roi,(roi[0]+det.roi_size,roi[1]+det.roi_size),(0,165,255),2)
cv2.imwrite('gui_rois.png',vis)
