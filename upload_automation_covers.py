import urllib.request
import urllib.parse
import json

automation_images = [
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600573472591-ee6b68d14c68?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=1920&q=80',
]

def upload_image(idx, src_url):
    filename = f"capas/automacao/modelo_automacao_{idx}.jpg"
    target_url = f"https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o?uploadType=media&name={urllib.parse.quote(filename, safe='')}"
    
    try:
        req_src = urllib.request.Request(src_url, headers={'User-Agent': 'Mozilla/5.0'})
        img_bytes = urllib.request.urlopen(req_src).read()
        
        req_up = urllib.request.Request(target_url, data=img_bytes, headers={'Content-Type': 'image/jpeg'}, method='POST')
        resp = urllib.request.urlopen(req_up)
        print(f"[SUCCESS] Uploaded {filename} -> Status: {resp.getcode()}")
        return True
    except Exception as e:
        err_msg = ""
        if hasattr(e, 'read'):
            err_msg = e.read().decode('utf-8', errors='ignore')
        print(f"[FAIL] Upload {filename} -> Error: {e} | {err_msg}")
        return False

print("Starting upload of automation covers to Firebase Storage...")
success_count = 0
for i in range(1, 101):
    src = automation_images[(i - 1) % len(automation_images)]
    if upload_image(i, src):
        success_count += 1

print(f"Upload complete! {success_count}/100 uploaded.")
