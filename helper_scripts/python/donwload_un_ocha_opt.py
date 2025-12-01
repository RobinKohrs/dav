# download most of the data from this map
# https://gis.unocha.org/portal/apps/experiencebuilder/experience/?id=f05d3b43cd3347cfbd0ca299c00cec96

import requests
import json
import os
import re
import time
import sys

# --- CONFIGURATION ---
BASE_URL = "https://gis.unocha.org/server/rest/services/Hosted"
DOWNLOAD_FOLDER = "downloads_qgis_ready"

# CRITICAL FIX FOR QGIS: Use 4326 (Lat/Lon WGS84) instead of 102100 (Meters)
CRS = "4326" 

# Threshold: If a layer is bigger than this, ask the user. Otherwise, just take it.
LARGE_LAYER_THRESHOLD = 100000

# Keywords to find the specific data
KEYWORDS = [
    "Obstacle", "Barrier", "Checkpoint", "Road", "Palestine", 
    "Gaza", "West Bank", "Crossing", "Fence", "Gate"
]
# ---------------------

def sanitize_filename(name):
    """Cleans up names to be safe for file saving"""
    return re.sub(r'[^\w\-_\. ]', '_', name)

def get_layer_ids(layer_url):
    """
    Connects to the layer and returns the list of all Object IDs.
    Returns (list_of_ids, error_message)
    """
    try:
        r = requests.get(f"{layer_url}/query", params={
            "where": "1=1",
            "returnIdsOnly": "true",
            "f": "json"
        })
        if r.status_code != 200:
            return None, f"HTTP Error {r.status_code}"
        
        data = r.json()
        if "objectIds" in data:
            return data["objectIds"], None
        else:
            return None, "Layer does not support ID querying"
            
    except Exception as e:
        return None, str(e)

def download_in_chunks(layer_url, all_ids, total_count):
    """Downloads data in batches of 1000 using the IDs"""
    all_features = []
    chunk_size = 1000
    
    print(f"      -> Downloading {total_count} features in batches...")

    for i in range(0, total_count, chunk_size):
        chunk_ids = all_ids[i : i + chunk_size]
        id_string = ",".join(str(x) for x in chunk_ids)
        
        params = {
            "objectIds": id_string,
            "outFields": "*",
            "f": "geojson",
            "outSR": CRS
        }
        
        try:
            r_chunk = requests.get(f"{layer_url}/query", params=params)
            if r_chunk.status_code == 200:
                feat_data = r_chunk.json()
                batch_features = feat_data.get("features", [])
                all_features.extend(batch_features)
                
                # Progress bar effect
                percent = int((len(all_features) / total_count) * 100)
                sys.stdout.write(f"\r      Progress: {percent}% ({len(all_features)}/{total_count})")
                sys.stdout.flush()
            
            # Pause slightly to be polite to the server
            time.sleep(0.1)
            
        except Exception as e:
            print(f"\n      [!] Error on batch {i}: {e}")

    print("") # New line after progress bar
    return {
        "type": "FeatureCollection",
        "features": all_features
    }

def simple_download(layer_url):
    """Fallback for layers that don't support ID counting"""
    print("      -> Attempting simple download (no count available)...")
    params = {"where": "1=1", "outFields": "*", "f": "geojson", "outSR": CRS}
    r = requests.get(f"{layer_url}/query", params=params)
    if r.status_code == 200:
        return r.json()
    return None

def main():
    if not os.path.exists(DOWNLOAD_FOLDER):
        os.makedirs(DOWNLOAD_FOLDER)

    print(f"--- Smart Downloader (CRS: {CRS}) ---")
    print(f"--- Auto-downloading layers under {LARGE_LAYER_THRESHOLD} features ---")
    
    # 1. Get List of Services
    try:
        resp = requests.get(BASE_URL, params={"f": "json"})
        catalog = resp.json()
        services = catalog.get('services', [])
    except Exception as e:
        print(f"Error connecting to server: {e}")
        return

    # 2. Iterate Services
    for service in services:
        s_name = service['name'] 
        s_type = service['type']
        
        # Filter by Keyword
        if not any(k.lower() in s_name.lower() for k in KEYWORDS):
            continue
            
        if s_type != 'FeatureServer':
            continue

        clean_s_name = s_name.replace("Hosted/", "")
        service_url = f"https://gis.unocha.org/server/rest/services/{s_name}/FeatureServer"
        
        # 3. Get Layers inside
        try:
            l_resp = requests.get(service_url, params={"f": "json"})
            l_data = l_resp.json()
            
            if 'layers' not in l_data:
                continue

            for layer in l_data['layers']:
                l_name = layer['name']
                l_id = layer['id']
                full_layer_url = f"{service_url}/{l_id}"
                
                print(f"\nChecking: [{clean_s_name}] -> {l_name}")
                
                # 4. Check Size First
                ids, error = get_layer_ids(full_layer_url)
                
                should_download = False
                total_count = 0
                
                if ids is not None:
                    total_count = len(ids)
                    if total_count == 0:
                        print("   [x] Empty layer. Skipping.")
                        continue
                    
                    if total_count > LARGE_LAYER_THRESHOLD:
                        # ASK USER
                        print(f"   [!] LARGE LAYER DETECTED: {total_count} features.")
                        while True:
                            choice = input("      >> Do you want to download this huge layer? (y/n): ").lower().strip()
                            if choice in ['y', 'n']:
                                break
                        if choice == 'y':
                            should_download = True
                        else:
                            print("   Skipped.")
                    else:
                        # AUTO DOWNLOAD
                        print(f"   [OK] Size: {total_count} features. Auto-downloading...")
                        should_download = True
                else:
                    # Could not get ID count
                    print(f"   [?] Could not determine size. ({error})")
                    while True:
                        choice = input("      >> Download anyway? (y/n): ").lower().strip()
                        if choice in ['y', 'n']:
                            break
                    if choice == 'y':
                        should_download = True
                        
                # 5. Execute Download
                if should_download:
                    if ids:
                        geojson_data = download_in_chunks(full_layer_url, ids, total_count)
                    else:
                        geojson_data = simple_download(full_layer_url)
                    
                    if geojson_data and len(geojson_data.get('features', [])) > 0:
                        filename = f"{clean_s_name}___L{l_id}_{sanitize_filename(l_name)}.geojson"
                        filepath = os.path.join(DOWNLOAD_FOLDER, filename)
                        
                        with open(filepath, "w", encoding='utf-8') as f:
                            json.dump(geojson_data, f)
                        print(f"      [SUCCESS] Saved to: {filepath}")
                    else:
                        print("      [FAIL] Download resulted in empty file.")

        except Exception as e:
            print(f"Error scanning service {s_name}: {e}")

    print("\nAll done!")

if __name__ == "__main__":
    main()