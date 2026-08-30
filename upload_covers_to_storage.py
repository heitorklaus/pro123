import os
import glob
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

BUCKET_NAME = "solardino-aea02.appspot.com"
FOLDER = "capas/energiasolar"
COVERS_DIR = os.path.join(os.path.dirname(__file__), "assets", "modelo_propostas")

def upload_file(file_path):
    file_name = os.path.basename(file_path)
    encoded_name = urllib.parse.quote(f"{FOLDER}/{file_name}", safe="")
    url = f"https://firebasestorage.googleapis.com/v0/b/{BUCKET_NAME}/o?uploadType=media&name={encoded_name}"
    
    with open(file_path, "rb") as f:
        data = f.read()
    
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "image/jpeg"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status in (200, 201):
            return file_name
    raise Exception(f"Status: {resp.status}")

def main():
    cover_files = sorted(glob.glob(os.path.join(COVERS_DIR, "modelo_proposta_*.jpg")), 
                         key=lambda x: int(''.join(filter(str.isdigit, os.path.basename(x))) or 0))
    print(f"Iniciando upload de {len(cover_files)} capas para Firebase Storage '{BUCKET_NAME}/{FOLDER}'...")
    
    success_count = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(upload_file, fp): fp for fp in cover_files}
        for future in as_completed(futures):
            fp = futures[future]
            fn = os.path.basename(fp)
            try:
                res = future.result()
                success_count += 1
                if success_count % 10 == 0 or success_count == len(cover_files):
                    print(f"[{success_count}/{len(cover_files)}] {fn} OK!")
            except Exception as e:
                print(f"[ERRO] {fn}: {e}")

    print(f"\nUpload concluido com sucesso: {success_count}/{len(cover_files)} capas no Storage!")

if __name__ == "__main__":
    main()
